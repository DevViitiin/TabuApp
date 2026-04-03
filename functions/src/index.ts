// functions/src/index.ts
import { onSchedule }         from "firebase-functions/v2/scheduler";
import { onRequest, onCall, HttpsError } from "firebase-functions/v2/https";
import { onValueWritten }     from "firebase-functions/v2/database";
import { initializeApp }      from "firebase-admin/app";
import { getDatabase }        from "firebase-admin/database";
import { getAuth }            from "firebase-admin/auth";
import * as nodemailer         from "nodemailer";

initializeApp();

// ══════════════════════════════════════════════════════════════════════════════
//  TIPOS
// ══════════════════════════════════════════════════════════════════════════════
type AcaoTipo =
  | "advertencia"
  | "suspensao"
  | "banimento"
  | "remover_conteudo"
  | "ignorar";

type DenunciaTipo = "posts" | "stories" | "users" | "chats";

interface ProcessarDenunciaData {
  denunciaId: string;
  denunciaTipo: DenunciaTipo;
  acao: AcaoTipo;
  motivoAdmin?: string;
  artigoViolado?: string;
  suspensaoInicio?: number;
  suspensaoFim?: number;
}

interface Denuncia {
  reporter_uid?: string;
  reporter_id?: string;
  post_owner_id?: string;
  story_owner_id?: string;
  reported_uid?: string;
  reported_user_id?: string;
  post_id?: string;
  story_id?: string;
  chat_id?: string;
  motivo_label?: string;
  motivo?: string;
  artigo?: string;
  status?: string;
}

interface Penalidade {
  protocolo: string;
  acao: AcaoTipo;
  motivo: string;
  motivo_admin: string;
  artigo_violado: string;
  aplicada_em: number;
  aplicada_por: string;
  denuncia_id: string;
  denuncia_tipo: DenunciaTipo;
  tipo?: string;
  suspensao_inicio?: number;
  suspensao_fim?: number;
  conteudo_removido?: string;
  conteudo_tipo?: string;
  vista?: boolean;
}

interface UserSuspenso {
  suspenso?: boolean;
  suspensao_fim?: number;
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS — FORMATAÇÃO
// ══════════════════════════════════════════════════════════════════════════════
function formatarData(ms: number): string {
  return new Date(ms).toLocaleDateString("pt-BR", {
    day: "2-digit", month: "long", year: "numeric",
    hour: "2-digit", minute: "2-digit",
    timeZone: "America/Sao_Paulo",
  });
}

function formatarDataCurta(ms: number): string {
  return new Date(ms).toLocaleDateString("pt-BR", {
    day: "2-digit", month: "long", year: "numeric",
    timeZone: "America/Sao_Paulo",
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS — EMAIL BASE
// ══════════════════════════════════════════════════════════════════════════════
const getTransporter = (): nodemailer.Transporter =>
  nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER ?? "",
      pass: process.env.EMAIL_PASS ?? "",
    },
  });

// ── Base do template ──────────────────────────────────────────────────────────
function baseTemplate(opts: {
  accentColor: string;
  badgeLabel:  string;
  titulo:      string;
  subtitulo:   string;
  corpo:       string;
  protocolo?:  string;
  agora:       number;
}): string {
  const { accentColor, badgeLabel, titulo, subtitulo, corpo, protocolo, agora } = opts;
  return `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${titulo}</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@700;800&display=swap');
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #07000F; font-family: 'Space Mono', monospace; color: #fff; -webkit-text-size-adjust: 100%; }
    .wrap  { max-width: 620px; margin: 0 auto; padding: 32px 16px 48px; }
    .neon  { height: 3px; width: 100%; background: linear-gradient(90deg,
               ${accentColor}33, ${accentColor}, #fff, ${accentColor}, ${accentColor}33); margin-bottom: 32px; }
    .badge { display: inline-block; background: ${accentColor}; padding: 4px 12px;
             font-size: 9px; font-weight: 700; letter-spacing: 3px; color: #fff; margin-bottom: 16px; }
    .logo  { font-family: 'Syne', sans-serif; font-size: 11px; letter-spacing: 6px;
             color: rgba(255,255,255,0.25); margin-bottom: 8px; }
    .titulo { font-family: 'Syne', sans-serif; font-size: 26px; letter-spacing: 4px;
              font-weight: 800; color: #fff; line-height: 1.2; margin-bottom: 6px; }
    .subtitulo { font-size: 9px; letter-spacing: 3px; color: rgba(255,255,255,0.3); margin-bottom: 32px; }
    .sep   { height: 1px; background: rgba(255,255,255,0.07); margin: 24px 0; }
    .card  { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08);
             padding: 24px; margin-bottom: 16px; }
    .card-accent { background: ${accentColor}0A; border: 1px solid ${accentColor}40; padding: 20px; margin-bottom: 16px; }
    .lbl   { font-size: 8px; font-weight: 700; letter-spacing: 2.5px; color: rgba(255,255,255,0.3);
             margin-bottom: 6px; display: block; }
    .val   { font-size: 13px; color: rgba(255,255,255,0.8); line-height: 1.7; }
    .chip  { display: inline-block; border: 1px solid ${accentColor}66; background: ${accentColor}15;
             padding: 4px 10px; font-size: 9px; font-weight: 700; letter-spacing: 1.5px; color: ${accentColor}; }
    .motivo-box { border-left: 2px solid ${accentColor}99; padding: 14px 16px; margin: 16px 0;
                  background: rgba(255,255,255,0.02); }
    .motivo-box p { font-size: 13px; line-height: 1.8; color: rgba(255,255,255,0.65); }
    .proto-box { background: ${accentColor}0D; border: 1px solid ${accentColor}55; padding: 18px 20px; margin: 16px 0; }
    .proto-lbl { font-size: 8px; font-weight: 700; letter-spacing: 3px; color: rgba(255,255,255,0.35); margin-bottom: 8px; }
    .proto-val { font-family: 'Syne', sans-serif; font-size: 20px; letter-spacing: 3px;
                 font-weight: 800; color: ${accentColor}; }
    .info-row  { display: flex; gap: 12px; margin-bottom: 10px; }
    .info-label { font-size: 8px; font-weight: 700; letter-spacing: 2px; color: rgba(255,255,255,0.25);
                  min-width: 90px; padding-top: 2px; }
    .info-value { font-size: 11px; color: rgba(255,255,255,0.65); line-height: 1.5; }
    .aviso { background: rgba(232,93,93,0.06); border: 1px solid rgba(232,93,93,0.3);
             padding: 14px 16px; margin: 16px 0; }
    .aviso p { font-size: 12px; line-height: 1.65; color: rgba(255,255,255,0.55); }
    .sucesso { background: rgba(76,175,80,0.06); border: 1px solid rgba(76,175,80,0.3);
               padding: 14px 16px; margin: 16px 0; }
    .sucesso p { font-size: 12px; line-height: 1.65; color: rgba(255,255,255,0.55); }
    .periodo { display: flex; gap: 0; margin: 16px 0; border: 1px solid ${accentColor}40; }
    .periodo-bloco { flex: 1; padding: 14px 16px; text-align: center; }
    .periodo-bloco:not(:last-child) { border-right: 1px solid ${accentColor}30; }
    .periodo-lbl { font-size: 7px; font-weight: 700; letter-spacing: 2px; color: ${accentColor}99; margin-bottom: 6px; }
    .periodo-val { font-size: 12px; font-weight: 700; color: rgba(255,255,255,0.8); line-height: 1.4; }
    .conseq { background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.06);
              padding: 16px; margin: 16px 0; }
    .conseq ul { list-style: none; padding: 0; }
    .conseq ul li { font-size: 11px; color: rgba(255,255,255,0.4); line-height: 1.8; padding-left: 14px; position: relative; }
    .conseq ul li::before { content: "—"; position: absolute; left: 0; color: ${accentColor}66; }
    .footer { border-top: 1px solid rgba(255,255,255,0.06); padding-top: 24px;
              margin-top: 32px; font-size: 9px; color: rgba(255,255,255,0.2); line-height: 2; }
    .footer a { color: ${accentColor}; text-decoration: none; }
    .destaque { color: ${accentColor}; }
    @media (max-width: 600px) {
      .wrap { padding: 20px 12px 40px; }
      .titulo { font-size: 20px; }
      .periodo { flex-direction: column; }
      .periodo-bloco:not(:last-child) { border-right: none; border-bottom: 1px solid ${accentColor}30; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="neon"></div>
    <div class="logo">TABU · SISTEMA OFICIAL</div>
    <div class="badge">${badgeLabel}</div>
    <div class="titulo">${titulo}</div>
    <div class="subtitulo">${subtitulo}</div>
    ${corpo}
    ${protocolo ? `
    <div class="proto-box">
      <div class="proto-lbl">NÚMERO DE PROTOCOLO — GUARDE ESTA INFORMAÇÃO</div>
      <div class="proto-val">${protocolo}</div>
    </div>` : ""}
    <div class="footer">
      <p>E-mail automático gerado em <strong>${formatarData(agora)}</strong></p>
      <p>Este é um e-mail oficial do sistema Tabu. Não responda a este endereço diretamente.</p>
      <p>Dúvidas ou contestações: <a href="mailto:tabuadministrative@gmail.com">tabuadministrative@gmail.com</a></p>
      ${protocolo ? `<p>Informe sempre o protocolo <strong>${protocolo}</strong> em qualquer contato.</p>` : ""}
      <p style="margin-top:16px; color: rgba(255,255,255,0.1);">
        TABU BAR & LOUNGE · Plataforma de entretenimento noturno · Termos de Uso aplicáveis
      </p>
    </div>
  </div>
</body>
</html>`;
}

// ══════════════════════════════════════════════════════════════════════════════
//  TEMPLATES DE EMAIL — DENUNCIADO
// ══════════════════════════════════════════════════════════════════════════════

function emailAdvertenciaReportado(opts: {
  nome: string; artigo: string; motivo: string;
  protocolo: string; agora: number; denunciaMotivo: string;
}): string {
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>⚠️ &nbsp;<strong>Sua conta recebeu uma Advertência Formal</strong> registrada pela equipe do Tabu.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Esta notificação é oficial e permanece registrada no seu histórico de conduta na plataforma.</p>
    </div>
    <div class="card">
      <span class="lbl">ARTIGO VIOLADO</span>
      <div class="chip">${opts.artigo}</div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TABU</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">O QUE ACONTECE AGORA</span>
      <ul>
        <li>Esta advertência fica registrada permanentemente no seu histórico.</li>
        <li>Seu acesso à plataforma não foi bloqueado neste momento.</li>
        <li>Reincidências resultarão em penalidades progressivas.</li>
        <li>Em caso de nova violação, a punição pode ser suspensão ou banimento permanente.</li>
      </ul>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.35); font-size:11px; line-height:1.7; margin-top:16px;">
      Caso acredite que esta advertência foi aplicada de forma incorreta, entre em contato 
      com nossa equipe informando o protocolo acima.
    </p>`;

  return baseTemplate({
    accentColor: "#D4AF37",
    badgeLabel:  "PENALIDADE · ADVERTÊNCIA",
    titulo:      "ADVERTÊNCIA FORMAL",
    subtitulo:   "NOTIFICAÇÃO OFICIAL DE CONDUTA · TABU",
    corpo,
    protocolo: opts.protocolo,
    agora: opts.agora,
  });
}

function emailSuspensaoReportado(opts: {
  nome: string; artigo: string; motivo: string; protocolo: string;
  inicioMs: number; fimMs: number; agora: number; denunciaMotivo: string;
}): string {
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>🚫 &nbsp;<strong>Sua conta foi suspensa temporariamente</strong> por decisão da equipe do Tabu.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Após análise da denúncia registrada contra sua conta, a equipe do Tabu determinou a aplicação de suspensão temporária conforme os Termos de Uso da plataforma.</p>
    </div>
    <div class="card">
      <span class="lbl">PERÍODO DE SUSPENSÃO</span>
      <div class="periodo">
        <div class="periodo-bloco">
          <div class="periodo-lbl">INÍCIO</div>
          <div class="periodo-val">${formatarDataCurta(opts.inicioMs)}</div>
        </div>
        <div class="periodo-bloco">
          <div class="periodo-lbl">TÉRMINO</div>
          <div class="periodo-val">${formatarDataCurta(opts.fimMs)}</div>
        </div>
      </div>
      <div class="sep"></div>
      <span class="lbl">ARTIGO VIOLADO</span>
      <div class="chip">${opts.artigo}</div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TABU</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">O QUE ISSO SIGNIFICA</span>
      <ul>
        <li>Seu acesso ao Tabu está bloqueado durante o período indicado acima.</li>
        <li>Ao término, o acesso será restaurado automaticamente — nenhuma ação é necessária.</li>
        <li>Tentativas de criar novas contas para burlar a suspensão são vedadas pelos Termos de Uso.</li>
        <li>Esta suspensão fica registrada no seu histórico de conduta.</li>
        <li>Nova violação após o retorno pode resultar em banimento permanente.</li>
      </ul>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.35); font-size:11px; line-height:1.7; margin-top:16px;">
      Para solicitar revisão antecipada desta decisão, entre em contato com nossa equipe 
      informando o número de protocolo abaixo.
    </p>`;

  return baseTemplate({
    accentColor: "#FF8C00",
    badgeLabel:  "PENALIDADE · SUSPENSÃO",
    titulo:      "CONTA SUSPENSA",
    subtitulo:   "ACESSO TEMPORARIAMENTE BLOQUEADO · TABU",
    corpo,
    protocolo: opts.protocolo,
    agora: opts.agora,
  });
}

function emailBanimentoReportado(opts: {
  nome: string; artigo: string; motivo: string;
  protocolo: string; agora: number; denunciaMotivo: string;
}): string {
  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>⛔ &nbsp;<strong>Sua conta foi permanentemente banida</strong> da plataforma Tabu.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Após análise detalhada pela equipe do Tabu, foi determinado o banimento permanente da sua conta em razão de violação grave dos Termos de Uso da plataforma.</p>
    </div>
    <div class="card">
      <span class="lbl">ARTIGO VIOLADO</span>
      <div class="chip">${opts.artigo}</div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TABU</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">O QUE ISSO SIGNIFICA</span>
      <ul>
        <li>Seu acesso ao Tabu foi revogado de forma permanente e definitiva.</li>
        <li>Sua conta e todos os dados associados poderão ser removidos conforme nossa Política de Privacidade.</li>
        <li>Tentativas de criar novas contas são vedadas e sujeitas a medidas legais (Art. 20º – TU).</li>
        <li>O Tabu reserva-se o direito de acionar as autoridades competentes quando necessário.</li>
      </ul>
    </div>
    <div class="card" style="border-color: rgba(255,255,255,0.06);">
      <span class="lbl">CONTESTAÇÃO FORMAL</span>
      <p class="val" style="margin-bottom:12px;">
        Se acredita que esta decisão foi tomada de forma incorreta, você pode contestá-la 
        formalmente por e-mail. Inclua obrigatoriamente o número de protocolo no assunto da mensagem.
      </p>
      <div class="info-row">
        <span class="info-label">E-MAIL</span>
        <span class="info-value" style="color: #E85D5D;">tabuadministrative@gmail.com</span>
      </div>
      <div class="info-row">
        <span class="info-label">ASSUNTO</span>
        <span class="info-value">Contestação — ${opts.protocolo}</span>
      </div>
    </div>`;

  return baseTemplate({
    accentColor: "#E85D5D",
    badgeLabel:  "PENALIDADE · BANIMENTO",
    titulo:      "CONTA BANIDA",
    subtitulo:   "ACESSO PERMANENTEMENTE REVOGADO · TABU",
    corpo,
    protocolo: opts.protocolo,
    agora: opts.agora,
  });
}

function emailConteudoRemovidoReportado(opts: {
  nome: string; artigo: string; motivo: string; protocolo: string;
  conteudoTipo: string; agora: number; denunciaMotivo: string;
}): string {
  const tipoLabel = opts.conteudoTipo === "posts"   ? "publicação" :
                    opts.conteudoTipo === "stories"  ? "story" :
                    opts.conteudoTipo === "chats"    ? "mensagem" : "conteúdo";

  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>🗑️ &nbsp;<strong>Um ${tipoLabel} seu foi removido</strong> da plataforma Tabu.</p></div>
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Após análise de uma denúncia registrada, a equipe do Tabu determinou a remoção do conteúdo abaixo conforme os Termos de Uso.</p>
    </div>
    <div class="card">
      <div class="info-row">
        <span class="info-label">TIPO</span>
        <span class="info-value">${tipoLabel.toUpperCase()}</span>
      </div>
      <div class="info-row">
        <span class="info-label">ARTIGO</span>
        <span class="info-value"><span class="chip">${opts.artigo}</span></span>
      </div>
      <div class="sep"></div>
      <span class="lbl">MOTIVO DA DENÚNCIA ORIGINAL</span>
      <p class="val" style="margin-bottom:16px;">${opts.denunciaMotivo}</p>
      <span class="lbl">POSIÇÃO OFICIAL DO TABU</span>
      <div class="motivo-box"><p>${opts.motivo}</p></div>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">O QUE ISSO SIGNIFICA</span>
      <ul>
        <li>O conteúdo foi removido permanentemente e não está mais acessível a nenhum usuário.</li>
        <li>Seu acesso à plataforma foi mantido neste momento.</li>
        <li>Esta remoção fica registrada no seu histórico de conduta.</li>
        <li>Reincidências podem resultar em advertência formal, suspensão ou banimento.</li>
        <li>Publicar conteúdo semelhante novamente poderá gerar penalidades mais severas.</li>
      </ul>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.35); font-size:11px; line-height:1.7; margin-top:16px;">
      Caso acredite que a remoção foi indevida, entre em contato com nossa equipe 
      informando o número de protocolo abaixo.
    </p>`;

  return baseTemplate({
    accentColor: "#E85D5D",
    badgeLabel:  "CONTEÚDO · REMOVIDO",
    titulo:      "CONTEÚDO REMOVIDO",
    subtitulo:   "NOTIFICAÇÃO OFICIAL DE REMOÇÃO · TABU",
    corpo,
    protocolo: opts.protocolo,
    agora: opts.agora,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  TEMPLATES DE EMAIL — DENUNCIANTE
// ══════════════════════════════════════════════════════════════════════════════

function emailDenunciaIgnorada(opts: {
  nome: string; denunciaMotivo: string; protocolo: string; agora: number;
}): string {
  const corpo = `
    <div class="card">
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Sua denúncia foi recebida e analisada cuidadosamente pela equipe do Tabu.</p>
      <div class="sep"></div>
      <span class="lbl">RESULTADO DA ANÁLISE</span>
      <div class="sucesso">
        <p>Após revisão detalhada, a equipe não identificou violações suficientes que justifiquem medidas disciplinares neste momento.</p>
      </div>
      <div class="info-row" style="margin-top:16px;">
        <span class="info-label">MOTIVO</span>
        <span class="info-value">${opts.denunciaMotivo}</span>
      </div>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">PRÓXIMOS PASSOS</span>
      <ul>
        <li>Esta denúncia foi arquivada como improcedente no sistema.</li>
        <li>O caso poderá ser reaberto mediante novas evidências.</li>
        <li>Continue reportando comportamentos inadequados — cada denúncia contribui para a segurança da comunidade.</li>
        <li>Em caso de urgência, entre em contato diretamente com nossa equipe.</li>
      </ul>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.4); font-size:11px; line-height:1.7; margin-top:16px;">
      Agradecemos sua contribuição para tornar o Tabu um ambiente mais seguro e respeitoso.
    </p>`;

  return baseTemplate({
    accentColor: "#8B6914",
    badgeLabel:  "DENÚNCIA · ANALISADA",
    titulo:      "DENÚNCIA REVISADA",
    subtitulo:   "RESULTADO DA ANÁLISE · TABU",
    corpo,
    protocolo: opts.protocolo,
    agora: opts.agora,
  });
}

function emailDenunciaResolvida(opts: {
  nome: string; acaoLabel: string; denunciaMotivo: string;
  artigo: string; protocolo: string; agora: number;
}): string {
  const corpo = `
    <div class="card">
      <p class="val" style="margin-bottom:16px;">Olá, <strong>${opts.nome}</strong>.</p>
      <p class="val">Sua denúncia foi revisada e <strong>medidas foram tomadas</strong> pela equipe do Tabu.</p>
      <div class="sep"></div>
      <div class="sucesso">
        <p>✅ &nbsp;<strong>Ação aplicada: ${opts.acaoLabel}</strong><br/>
        A situação foi tratada de acordo com os Termos de Uso da plataforma.</p>
      </div>
      <div class="info-row" style="margin-top:16px;">
        <span class="info-label">MOTIVO</span>
        <span class="info-value">${opts.denunciaMotivo}</span>
      </div>
      <div class="info-row">
        <span class="info-label">ARTIGO</span>
        <span class="info-value">${opts.artigo}</span>
      </div>
    </div>
    <div class="card" style="border-color:rgba(255,255,255,0.06);">
      <p class="val" style="font-size:11px; color:rgba(255,255,255,0.4); line-height:1.7;">
        Por respeito à privacidade de todos os envolvidos, os detalhes específicos 
        da penalidade aplicada não são divulgados ao denunciante. Sua contribuição 
        foi fundamental para manter a comunidade segura.
      </p>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.4); font-size:11px; line-height:1.7; margin-top:16px;">
      Agradecemos por ajudar a tornar o Tabu um ambiente mais seguro e respeitoso para todos.
    </p>`;

  return baseTemplate({
    accentColor: "#4CAF50",
    badgeLabel:  "DENÚNCIA · RESOLVIDA",
    titulo:      "MEDIDA APLICADA",
    subtitulo:   "SUA DENÚNCIA GEROU RESULTADO · TABU",
    corpo,
    protocolo: opts.protocolo,
    agora: opts.agora,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS — DATABASE
// ══════════════════════════════════════════════════════════════════════════════
function gerarProtocolo(): string {
  const ts   = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `TABU-${ts}-${rand}`;
}

async function getEmail(uid: string): Promise<string | null> {
  try {
    const snap = await getDatabase().ref(`Users/${uid}/email`).get();
    return snap.val() ?? null;
  } catch { return null; }
}

async function getNome(uid: string): Promise<string> {
  try {
    const snap = await getDatabase().ref(`Users/${uid}/name`).get();
    return snap.val() ?? uid;
  } catch { return uid; }
}

// ══════════════════════════════════════════════════════════════════════════════
//  1. PROCESSAR DENÚNCIA
// ══════════════════════════════════════════════════════════════════════════════
export const processarDenuncia = onCall<ProcessarDenunciaData>(
  { region: "us-central1" },
  async (request) => {
    const db = getDatabase();

    if (!request.auth) throw new HttpsError("unauthenticated", "Não autenticado.");
    const adminSnap = await db.ref(`Administratives/${request.auth.uid}`).get();
    if (!adminSnap.val()) throw new HttpsError("permission-denied", "Acesso negado.");

    const { denunciaId, denunciaTipo, acao, motivoAdmin, artigoViolado,
            suspensaoInicio, suspensaoFim } = request.data;

    if (!denunciaId || !denunciaTipo || !acao)
      throw new HttpsError("invalid-argument", "Dados insuficientes.");

    const denunciaRef  = db.ref(`Reports/${denunciaTipo}/${denunciaId}`);
    const denunciaSnap = await denunciaRef.get();
    if (!denunciaSnap.exists()) throw new HttpsError("not-found", "Denúncia não encontrada.");

    const denuncia  = denunciaSnap.val() as Denuncia;
    const protocolo = gerarProtocolo();
    const agora     = Date.now();

    const reporterUid: string | null =
      denuncia.reporter_uid ?? denuncia.reporter_id ?? null;
    const reportedUid: string | null =
      denuncia.post_owner_id ?? denuncia.story_owner_id ??
      denuncia.reported_uid  ?? denuncia.reported_user_id ?? null;
    const conteudoId: string | null =
      denuncia.post_id ?? denuncia.story_id ?? denuncia.chat_id ?? null;

    const [reporterEmail, reportedEmail, reporterNome, reportedNome] =
      await Promise.all([
        reporterUid ? getEmail(reporterUid) : null,
        reportedUid ? getEmail(reportedUid) : null,
        reporterUid ? getNome(reporterUid)  : "Usuário",
        reportedUid ? getNome(reportedUid)  : "Usuário",
      ]);

    const descricaoInfracao = motivoAdmin?.trim() ?? "";
    const artigoFinal       = artigoViolado ?? denuncia.artigo ?? "—";
    const denunciaMotivo    = denuncia.motivo_label ?? denuncia.motivo ?? "—";

    // FIX: vista: false — o usuário verá a penalidade ao fazer login
    const penalidade: Penalidade = {
      protocolo,
      acao,
      motivo:         denunciaMotivo,
      motivo_admin:   descricaoInfracao,
      artigo_violado: artigoFinal,
      aplicada_em:    agora,
      aplicada_por:   request.auth.uid,
      denuncia_id:    denunciaId,
      denuncia_tipo:  denunciaTipo,
      vista:          false, // ← usuário verá ao próximo login
    };

    const updates: Record<string, unknown> = {};

    // ── IGNORAR ────────────────────────────────────────────────────────────
    if (acao === "ignorar") {
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "dismissed";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
      updates[`Reports/${denunciaTipo}/${denunciaId}/admin_uid`]    = request.auth.uid;
    }

    // ── ADVERTÊNCIA ────────────────────────────────────────────────────────
    if (acao === "advertencia" && reportedUid) {
      const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
      updates[`Users/${reportedUid}/penalidades/${penRef.key}`]     = { ...penalidade, tipo: "advertencia" };
      updates[`Users/${reportedUid}/penalidade_ativa`]              = "advertencia";
      updates[`Users/${reportedUid}/report_count`]                  = { ".sv": "increment" } as any;
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "advertencia";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
    }

    // ── SUSPENSÃO ──────────────────────────────────────────────────────────
    if (acao === "suspensao" && reportedUid) {
      const inicio = suspensaoInicio ?? agora;
      const fim    = suspensaoFim    ?? agora + 7 * 24 * 60 * 60 * 1000;
      const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
      updates[`Users/${reportedUid}/penalidades/${penRef.key}`]     = {
        ...penalidade, tipo: "suspensao",
        suspensao_inicio: inicio, suspensao_fim: fim,
        vista: true, // suspensão é tratada como tela separada, não como popup
      };
      updates[`Users/${reportedUid}/suspenso`]                      = true;
      updates[`Users/${reportedUid}/suspensao_fim`]                 = fim;
      updates[`Users/${reportedUid}/penalidade_ativa`]              = "suspensao";
      updates[`Users/${reportedUid}/report_count`]                  = { ".sv": "increment" } as any;
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "suspensao";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
    }

    // ── BANIMENTO ──────────────────────────────────────────────────────────
    if (acao === "banimento" && reportedUid) {
      const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
      updates[`Users/${reportedUid}/penalidades/${penRef.key}`]     = {
        ...penalidade, tipo: "banimento",
        vista: true, // banimento é tratado como tela separada
      };
      updates[`Users/${reportedUid}/banido`]                        = true;
      updates[`Users/${reportedUid}/banido_em`]                     = agora;
      updates[`Users/${reportedUid}/penalidade_ativa`]              = "banimento";
      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "banimento";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;
      try { await getAuth().updateUser(reportedUid, { disabled: true }); } catch { /* ignore */ }
    }

    // ── REMOÇÃO DE CONTEÚDO ────────────────────────────────────────────────
    if (acao === "remover_conteudo" && conteudoId) {
      let contentPath: string | null = null;
      if (denunciaTipo === "posts")   contentPath = `Posts/post/${conteudoId}`;
      if (denunciaTipo === "stories") contentPath = `Posts/story/${conteudoId}`;
      if (denunciaTipo === "chats")   contentPath = `Chats/${conteudoId}`;
      if (contentPath) updates[contentPath] = null;

      updates[`Reports/${denunciaTipo}/${denunciaId}/status`]       = "actioned";
      updates[`Reports/${denunciaTipo}/${denunciaId}/acao_tomada`]  = "remover_conteudo";
      updates[`Reports/${denunciaTipo}/${denunciaId}/resolvido_em`] = agora;
      updates[`Reports/${denunciaTipo}/${denunciaId}/protocolo`]    = protocolo;

      if (reportedUid) {
        const penRef = db.ref(`Users/${reportedUid}/penalidades`).push();
        updates[`Users/${reportedUid}/penalidades/${penRef.key}`] = {
          ...penalidade,
          tipo:               "remover_conteudo",
          conteudo_removido:  conteudoId,
          conteudo_tipo:      denunciaTipo,
          vista:              false, // ← usuário verá popup ao próximo login
        };
      }
    }

    await db.ref().update(updates);

    // Arquivar
    const arquivoSnap = await denunciaRef.get();
    if (arquivoSnap.exists()) {
      await db.ref(`Arquivo/${protocolo}`).set({
        ...arquivoSnap.val(), protocolo, arquivado_em: agora, acao_final: acao,
      });
    }

    // ══════════════════════════════════════════════════════════════════════
    //  ENVIO DE EMAILS
    // ══════════════════════════════════════════════════════════════════════
    const emailUser = process.env.EMAIL_USER ?? "";
    const transporter = getTransporter();

    const acaoLabels: Record<string, string> = {
      advertencia:      "ADVERTÊNCIA FORMAL",
      suspensao:        "SUSPENSÃO TEMPORÁRIA",
      banimento:        "BANIMENTO PERMANENTE",
      remover_conteudo: "REMOÇÃO DE CONTEÚDO",
      ignorar:          "ARQUIVADO SEM MEDIDAS",
    };
    const acaoLabelStr = acaoLabels[acao] ?? acao.toUpperCase();

    // ── Email → DENUNCIANTE (ignorar) ──────────────────────────────────────
    if (acao === "ignorar" && reporterEmail) {
      await transporter.sendMail({
        from:    `"Tabu · Suporte" <${emailUser}>`,
        to:      reporterEmail,
        subject: `[${protocolo}] Sua denúncia foi analisada — Tabu`,
        html:    emailDenunciaIgnorada({
          nome: reporterNome, denunciaMotivo: denunciaMotivo,
          protocolo, agora,
        }),
      });
      return { sucesso: true, protocolo };
    }

    // ── Email → DENUNCIADO ─────────────────────────────────────────────────
    if (reportedEmail) {
      let htmlReportado = "";
      if (acao === "advertencia") {
        htmlReportado = emailAdvertenciaReportado({
          nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao,
          protocolo, agora, denunciaMotivo,
        });
      } else if (acao === "suspensao") {
        htmlReportado = emailSuspensaoReportado({
          nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao,
          protocolo, agora, denunciaMotivo,
          inicioMs: suspensaoInicio ?? agora,
          fimMs:    suspensaoFim    ?? agora + 7 * 24 * 60 * 60 * 1000,
        });
      } else if (acao === "banimento") {
        htmlReportado = emailBanimentoReportado({
          nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao,
          protocolo, agora, denunciaMotivo,
        });
      } else if (acao === "remover_conteudo") {
        htmlReportado = emailConteudoRemovidoReportado({
          nome: reportedNome, artigo: artigoFinal, motivo: descricaoInfracao,
          protocolo, agora, denunciaMotivo,
          conteudoTipo: denunciaTipo,
        });
      }

      if (htmlReportado) {
        await transporter.sendMail({
          from:    `"Tabu · Suporte" <${emailUser}>`,
          to:      reportedEmail,
          subject: `[${protocolo}] Notificação de penalidade: ${acaoLabelStr} — Tabu`,
          html:    htmlReportado,
        });
      }
    }

    // ── Email → DENUNCIANTE ────────────────────────────────────────────────
    if (reporterEmail) {
      await transporter.sendMail({
        from:    `"Tabu · Suporte" <${emailUser}>`,
        to:      reporterEmail,
        subject: `[${protocolo}] Medidas aplicadas à sua denúncia — Tabu`,
        html:    emailDenunciaResolvida({
          nome: reporterNome, acaoLabel: acaoLabelStr,
          denunciaMotivo, artigo: artigoFinal, protocolo, agora,
        }),
      });
    }

    return { sucesso: true, protocolo };
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  2. VERIFICAR SUSPENSÕES
// ══════════════════════════════════════════════════════════════════════════════
export const verificarSuspensoes = onSchedule(
  { schedule: "every 1 hours", timeZone: "America/Sao_Paulo", region: "us-central1" },
  async () => {
    const db    = getDatabase();
    const agora = Date.now();

    const snap = await db.ref("Users").orderByChild("suspenso").equalTo(true).get();
    if (!snap.exists()) return;

    const updates: Record<string, null> = {};
    snap.forEach((child) => {
      const user = child.val() as UserSuspenso;
      const uid  = child.key as string;
      if (user.suspensao_fim && user.suspensao_fim <= agora) {
        updates[`Users/${uid}/suspenso`]                = null;
        updates[`Users/${uid}/suspensao_fim`]           = null;
        updates[`Users/${uid}/penalidade_ativa`]        = null;
        updates[`Users/${uid}/reativacao_solicitada`]   = null;
        updates[`Users/${uid}/reativacao_solicitada_em`]= null;
      }
    });

    if (Object.keys(updates).length > 0) await db.ref().update(updates);
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  3. ARQUIVAMENTO DE FESTAS
// ══════════════════════════════════════════════════════════════════════════════
async function _arquivarFestasVencidas(): Promise<{ arquivadas: number; timestamp: string }> {
  const db        = getDatabase();
  const festasRef = db.ref("Festas");
  const now       = Date.now();
  const snap = await festasRef.once("value");
  if (!snap.exists()) return { arquivadas: 0, timestamp: new Date().toISOString() };

  const updates: Record<string, string> = {};
  let count = 0;
  snap.forEach((child) => {
    const festa   = child.val() as Record<string, unknown>;
    const festaId = child.key as string;
    const dataFim = festa?.data_fim as number | undefined;
    const status  = (festa?.status as string | undefined) ?? "ativa";
    if (status === "ativa" && typeof dataFim === "number" && dataFim < now) {
      updates[`${festaId}/status`] = "arquivada";
      count++;
    }
  });

  if (count > 0) await festasRef.update(updates);
  return { arquivadas: count, timestamp: new Date().toISOString() };
}

export const scheduleArchiveParties = onSchedule(
  { schedule: "every 1 hours", timeZone: "America/Sao_Paulo", region: "southamerica-east1" },
  async () => { await _arquivarFestasVencidas(); }
);

export const archivePartiesHttp = onRequest(
  { region: "southamerica-east1" },
  async (req, res) => {
    const secret = process.env.ARCHIVE_SECRET ?? "tabu-archive-2025";
    if (req.query["key"] !== secret) { res.status(403).json({ error: "Unauthorized" }); return; }
    const result = await _arquivarFestasVencidas();
    res.json(result);
  }
);

// ══════════════════════════════════════════════════════════════════════════════
//  4. BADGE DE CHATS NÃO LIDOS
// ══════════════════════════════════════════════════════════════════════════════
export const updateUnreadChatsCount = onValueWritten(
  { ref: "Chats/{chatId}/unreadCount/{uid}", region: "us-central1" },
  async (event) => {
    const { uid } = event.params;
    const db = getDatabase();
    const userChatsSnap = await db.ref(`UserChats/${uid}`).get();
    if (!userChatsSnap.exists()) { await db.ref(`Users/${uid}/unreadChatsCount`).set(0); return null; }

    const chatIds = Object.keys(userChatsSnap.val() as Record<string, unknown>);
    const snaps = await Promise.all(chatIds.map((id) => db.ref(`Chats/${id}/unreadCount/${uid}`).get()));
    const count = snaps.reduce((acc, snap) => {
      const val = snap.val();
      return acc + (typeof val === "number" && val > 0 ? 1 : 0);
    }, 0);
    await db.ref(`Users/${uid}/unreadChatsCount`).set(count);
    return null;
  }
);

type AcaoPedidoConvite = "aprovar" | "rejeitar";

interface ProcessarPedidoConviteData {
  pedidoId:        string;
  acao:            AcaoPedidoConvite;
  motivoRejeicao?: string;
}

// ══════════════════════════════════════════════════════════════════════════════
//  TEMPLATE — CONVITE APROVADO (enviado ao solicitante)
// ══════════════════════════════════════════════════════════════════════════════
function emailConviteAprovado(opts: {
  nome: string; codigo: string; protocolo: string; agora: number;
}): string {
  const corpo = `
    <div class="card-accent">
      <div class="sucesso"><p>✅ &nbsp;<strong>Sua solicitação de acesso foi aprovada.</strong></p></div>
      <p class="val" style="margin-bottom:16px;">Prezado(a) <strong>${opts.nome}</strong>,</p>
      <p class="val">
        Após análise da sua solicitação, a equipe administrativa do Tabu tem o prazer 
        de informar que seu acesso à plataforma foi <strong>aprovado</strong>.
      </p>
    </div>
    <div class="card">
      <span class="lbl">SEU CÓDIGO DE CONVITE</span>
      <div style="background:rgba(255,45,122,0.08);border:1px solid rgba(255,45,122,0.45);
                  padding:28px;text-align:center;margin:14px 0 10px;">
        <div style="font-family:'Syne',sans-serif;font-size:30px;font-weight:800;
                    letter-spacing:8px;color:#FF2D7A;">${opts.codigo}</div>
      </div>
      <p class="val" style="font-size:11px;color:rgba(255,255,255,0.4);line-height:1.7;">
        Este código é <strong>pessoal e intransferível</strong>. 
        Não o compartilhe com terceiros. O Tabu nunca solicitará seu código por outros meios.
      </p>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">COMO UTILIZAR</span>
      <ul>
        <li>Abra o aplicativo Tabu e selecione <strong>Criar conta</strong>.</li>
        <li>Quando solicitado, insira o código de convite acima.</li>
        <li>Complete o cadastro com as informações requeridas.</li>
        <li>Ao criar sua conta, você concorda com os Termos de Uso e a Política de Privacidade do Tabu.</li>
      </ul>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.3);font-size:11px;line-height:1.7;margin-top:16px;">
      Seja bem-vindo(a) à plataforma. Esperamos que aproveite a experiência.
    </p>`;

  return baseTemplate({
    accentColor: "#FF2D7A",
    badgeLabel:  "ACESSO · APROVADO",
    titulo:      "BEM-VINDO AO TABU",
    subtitulo:   "SUA SOLICITAÇÃO FOI APROVADA · ACESSO LIBERADO",
    corpo,
    protocolo:   opts.protocolo,
    agora:       opts.agora,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  TEMPLATE — CONVITE RECUSADO (enviado ao solicitante)
// ══════════════════════════════════════════════════════════════════════════════
function emailConviteRecusado(opts: {
  nome: string; motivo: string; protocolo: string; agora: number;
}): string {
  const motivoFinal = opts.motivo.trim() ||
    "Sua solicitação não atendeu aos critérios necessários para acesso à plataforma neste momento.";

  const corpo = `
    <div class="card-accent">
      <div class="aviso"><p>⚠️ &nbsp;<strong>Sua solicitação de acesso não foi aprovada.</strong></p></div>
      <p class="val" style="margin-bottom:16px;">Prezado(a) <strong>${opts.nome}</strong>,</p>
      <p class="val">
        Agradecemos seu interesse na plataforma Tabu. Após análise detalhada da sua 
        solicitação pela equipe administrativa, informamos que, no momento, não é 
        possível conceder o acesso requerido.
      </p>
    </div>
    <div class="card">
      <span class="lbl">FUNDAMENTAÇÃO DA DECISÃO</span>
      <div class="motivo-box"><p>${motivoFinal}</p></div>
    </div>
    <div class="conseq">
      <span class="lbl" style="margin-bottom:10px;">INFORMAÇÕES ADICIONAIS</span>
      <ul>
        <li>Esta decisão foi tomada com base nas políticas internas de acesso da plataforma.</li>
        <li>O Tabu reserva-se o direito de recusar acessos sem necessidade de justificativa adicional.</li>
        <li>Não é possível fornecer detalhes suplementares sobre os critérios de avaliação.</li>
        <li>Em caso de questionamento formal, entre em contato pelo e-mail abaixo, informando o protocolo.</li>
      </ul>
    </div>
    <p class="val" style="color:rgba(255,255,255,0.3);font-size:11px;line-height:1.7;margin-top:16px;">
      Agradecemos a compreensão. Atenciosamente, Equipe Tabu.
    </p>`;

  return baseTemplate({
    accentColor: "#E85D5D",
    badgeLabel:  "ACESSO · RECUSADO",
    titulo:      "SOLICITAÇÃO RECUSADA",
    subtitulo:   "SEU PEDIDO DE ACESSO NÃO FOI APROVADO · TABU",
    corpo,
    protocolo:   opts.protocolo,
    agora:       opts.agora,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  5. PROCESSAR PEDIDO DE CONVITE
// ══════════════════════════════════════════════════════════════════════════════
export const processarPedidoConvite = onCall<ProcessarPedidoConviteData>(
  { region: "us-central1" },
  async (request) => {
    const db = getDatabase();

    if (!request.auth)
      throw new HttpsError("unauthenticated", "Não autenticado.");

    const adminSnap = await db.ref(`Administratives/${request.auth.uid}`).get();
    if (!adminSnap.val())
      throw new HttpsError("permission-denied", "Acesso negado.");

    const { pedidoId, acao, motivoRejeicao } = request.data;

    if (!pedidoId || !acao)
      throw new HttpsError("invalid-argument", "Dados insuficientes.");

    const pedidoRef  = db.ref(`InviteRequests/${pedidoId}`);
    const pedidoSnap = await pedidoRef.get();

    if (!pedidoSnap.exists())
      throw new HttpsError("not-found", "Pedido não encontrado.");

    const pedido = pedidoSnap.val() as {
      uid: string; name: string; email: string; status: string;
    };

    if (pedido.status !== "pending")
      throw new HttpsError("failed-precondition", "Este pedido já foi processado.");

    const protocolo   = gerarProtocolo();
    const agora       = Date.now();
    const transporter = getTransporter();
    const emailUser   = process.env.EMAIL_USER ?? "";

    // ── APROVAR ─────────────────────────────────────────────────────────────
    if (acao === "aprovar") {
      // Busca o código de convite vigente
      // Ajuste o caminho conforme onde você armazena o código (InviteCode/code)
      const codigoSnap = await db.ref("Invitation_code").get();
      const codigo     = codigoSnap.val() as string | null;

      if (!codigo)
        throw new HttpsError("not-found", "Código de convite não configurado.");

      const updates: Record<string, unknown> = {
        [`InviteRequests/${pedidoId}/status`]:      "approved",
        [`InviteRequests/${pedidoId}/resolved_at`]: agora,
        [`InviteRequests/${pedidoId}/resolved_by`]: request.auth.uid,
        [`InviteRequests/${pedidoId}/protocolo`]:   protocolo,
        [`InviteRequestsArquivo/${protocolo}`]: {
          ...pedido, status: "approved",
          resolved_at: agora, resolved_by: request.auth.uid, protocolo,
        },
      };
      await db.ref().update(updates);

      if (pedido.email) {
        await transporter.sendMail({
          from:    `"Tabu · Suporte" <${emailUser}>`,
          to:      pedido.email,
          subject: `[${protocolo}] Seu acesso ao Tabu foi aprovado — Bem-vindo!`,
          html:    emailConviteAprovado({
            nome: pedido.name, codigo, protocolo, agora,
          }),
        });
      }

      return { sucesso: true, protocolo, acao: "aprovado" };
    }

    // ── REJEITAR ─────────────────────────────────────────────────────────────
    if (acao === "rejeitar") {
      const motivo = motivoRejeicao?.trim() ?? "";

      const updates: Record<string, unknown> = {
        [`InviteRequests/${pedidoId}/status`]:          "rejected",
        [`InviteRequests/${pedidoId}/resolved_at`]:     agora,
        [`InviteRequests/${pedidoId}/resolved_by`]:     request.auth.uid,
        [`InviteRequests/${pedidoId}/motivo_rejeicao`]: motivo,
        [`InviteRequests/${pedidoId}/protocolo`]:       protocolo,
        [`InviteRequestsArquivo/${protocolo}`]: {
          ...pedido, status: "rejected",
          resolved_at: agora, resolved_by: request.auth.uid,
          motivo_rejeicao: motivo, protocolo,
        },
      };
      await db.ref().update(updates);

      if (pedido.email) {
        await transporter.sendMail({
          from:    `"Tabu · Suporte" <${emailUser}>`,
          to:      pedido.email,
          subject: `[${protocolo}] Resposta à sua solicitação de acesso — Tabu`,
          html:    emailConviteRecusado({
            nome: pedido.name, motivo, protocolo, agora,
          }),
        });
      }

      return { sucesso: true, protocolo, acao: "rejeitado" };
    }

    throw new HttpsError("invalid-argument", "Ação inválida.");
  }
);
