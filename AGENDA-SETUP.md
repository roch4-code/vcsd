# Conectar login e agenda segura

O formulário abre o WhatsApp mesmo sem banco. Para habilitar login por e-mail, lista de horários, cancelamento e remarcação:

1. Crie um projeto Supabase.
2. No SQL Editor do projeto, execute o arquivo agenda-schema.sql.
3. Em Project Settings / API, copie o Project URL e a chave anon/publishable para supabase-config.js.
4. Nunca use uma chave service_role neste site.
5. Em Authentication, mantenha confirmação de e-mail habilitada e configure as URLs de redirecionamento para o domínio publicado.
6. Hospede o site em HTTPS. O login não funciona corretamente abrindo o arquivo diretamente com file://.
7. Abra o site publicado, crie uma conta com e-mail e senha, confirme o e-mail e entre. Os pedidos ficam pendentes até a clínica confirmar pelo WhatsApp.

A tabela patient_appointments permite que cada conta leia somente os próprios horários. O navegador não pode escrever diretamente na tabela: criar, remarcar e cancelar passam por funções do banco que verificam a sessão. Uma restrição no PostgreSQL bloqueia horários sobrepostos mesmo quando duas pessoas tentam marcar ao mesmo tempo.

A agenda usa períodos de uma hora entre 08h e 18h no horário de São Paulo. Confirme com a clínica os dias e horários de funcionamento antes de colocar a agenda no ar. O vídeo de demonstração é do Pexels; substitua por material da própria clínica quando disponível.
