# Segurança e configuração da clínica

## Controles preparados no código

- Login por e-mail e senha via Supabase Auth, recuperação por e-mail, mínimo de 12 caracteres na interface e aceite explícito dos Termos e da Política de privacidade no cadastro e na confirmação do agendamento.
- SQL ativa RLS, deixa cada paciente ler apenas seus horários e bloqueia gravação direta pelo navegador. Funções autenticadas validam propriedade antes de remarcar/cancelar; a restrição do banco bloqueia horários sobrepostos.
- A função de disponibilidade retorna apenas horários ocupados, sem nome, tratamento ou observações de outros pacientes.
- O site não contém chave service_role. O único valor previsto no frontend é a chave publicável anon/publishable.
- O arquivo _headers oferece CSP, HSTS, proteção contra MIME sniffing, política de referrer, bloqueio de framing e restrição de permissões para hospedagens estáticas que suportem esse formato.

## Antes de publicar

1. Preencher URL e chave publicável em supabase-config.js, executar agenda-schema.sql no projeto correto e publicar o site em HTTPS.
2. No Supabase, exigir confirmação de e-mail, restringir URLs de retorno ao domínio publicado e configurar limites/CAPTCHA de autenticação compatíveis com a operação.
3. Confirmar a razão social/CNPJ da clínica, contato do encarregado de dados e prazo de retenção para completar a Política de privacidade.
4. Configurar os mesmos cabeçalhos no provedor de hospedagem. O arquivo _headers é lido por Cloudflare Pages/Netlify; outros hosts exigem configuração própria.
5. Validar login, recuperação de senha, isolamento entre duas contas, colisão de horário e cancelamento/remarcação no projeto de produção.

## Limites conhecidos

- A conexão Supabase permanece desativada enquanto supabase-config.js estiver vazio. Por isso não há login, gravação ou remarcação de verdade nesta cópia.
- O site atual usa JavaScript inline; o CSP permite inline script/style para preservar essa implementação. Externalizar os scripts e adotar hashes ou nonces reduziria esse ponto de risco.
- A hospedagem, a confirmação de e-mail, CAPTCHA, cópias de segurança e monitoramento ainda precisam ser configurados e verificados. Não há verificação MFA de novo dispositivo nem painel de operação da clínica incluídos.
- O vídeo e o Instagram vêm de terceiros e podem receber dados técnicos do navegador conforme suas políticas.

