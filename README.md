💈 CorteCerto Mobile (Flutter)

Aplicação mobile para agendamento de horários em barbearia, desenvolvida em Flutter e integrada a uma API REST em Java Spring Boot.

O objetivo do projeto é permitir que clientes realizem o agendamento de serviços de forma simples, visual e segura diretamente pelo celular, evitando conflitos de horário e garantindo controle completo da agenda.

📱 Funcionalidades

Cadastro de cliente

Login com autenticação JWT

Listagem dinâmica de serviços

Visualização de agenda disponível em tempo real

Bloqueio automático de horários ocupados

Confirmação de agendamento com feedback visual

Redirecionamento automático após confirmação

Persistência de sessão (token seguro)

🧠 Regras de Negócio

O aplicativo não apenas envia dados para o backend — ele participa da lógica:

Apenas horários disponíveis são exibidos

Horários confirmados não podem ser selecionados

Concorrência protegida no backend

Feedback visual ao usuário quando agenda está cheia

Sessão reiniciada após conclusão do agendamento

🏗️ Arquitetura
<img width="408" height="293" alt="Arquitetura" src="https://github.com/user-attachments/assets/d4844011-3d5e-45c4-8891-91521fa3a47b" />
Camadas
Camada	Responsabilidade
presentation	UI (Widgets / Pages)
controller	Estado e fluxo da tela (ChangeNotifier)
data/api	Comunicação HTTP (Dio)
domain	Modelos da aplicação
🔐 Autenticação

O login utiliza JWT retornado pelo backend:

Token salvo com flutter_secure_storage

Enviado automaticamente nas requisições protegidas

Identidade do cliente extraída do token

Backend validado via Spring Security Filter

🧰 Tecnologias
Mobile

Flutter

Dart

Provider (state management)

Dio (HTTP client)

Secure Storage

Backend (API integrada)

Java 17

Spring Boot

Spring Security

JWT

JPA / Hibernate

SQLite

WebSocket (notificações futuras)

🔄 Fluxo do Usuário

Login / Cadastro
⬇
Seleção de Serviço
⬇
Escolha de Data
⬇
Horários disponíveis
⬇
Confirmação
⬇
Mensagem de sucesso
⬇
Retorno ao login

🖼️ Screenshots
🔐 Login
<img width="391" height="866" src="https://github.com/user-attachments/assets/95cfe54e-f41d-494d-877e-c3438c76ac7f" />
📝 Cadastro
<img width="386" height="858" src="https://github.com/user-attachments/assets/3b09a600-9b8d-4db4-b421-619d2357ccb1" />
💈 Serviços
<img width="386" height="864" src="https://github.com/user-attachments/assets/aab083bd-b626-452f-8b50-2590ac3fa617" />
📅 Agenda
<img width="385" height="858" src="https://github.com/user-attachments/assets/82e227b0-2a42-40ae-a0db-63bdb11bd25c" />
✅ Confirmação
<img width="388" height="859" src="https://github.com/user-attachments/assets/87f7fa67-4f39-4bf3-b4f2-ebefef5584cc" />
🚀 Objetivo do Projeto

Este projeto foi desenvolvido como estudo prático de:

Arquitetura mobile escalável

Integração Flutter + Spring Boot

Controle de concorrência em agendamento

Experiência do usuário em mobile

Organização profissional de código

👨‍💻 Autor

Marcos Eduardo
