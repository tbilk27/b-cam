# 🧠 b-cam • Centro de Contexto e Governança do Projeto

Bem-vindo ao repositório de conhecimento e decisões do projeto **b-cam**.

Este diretório contém a base viva de conhecimento do projeto, servindo como fonte única da verdade para todos os agentes de IA, desenvolvedores e stakeholders.

---

## 📂 Estrutura de Documentos

| Arquivo / Pasta | Responsável Principal | Propósito |
| :--- | :--- | :--- |
| [TEAM_ROLES.md](./TEAM_ROLES.md) | **Líder Orquestrador** | Definição dos papéis de cada agente, matriz RACI e protocolo de comunicação |
| [PROJECT_CHARTER.md](./PROJECT_CHARTER.md) | **Líder Orquestrador** | Visão do produto, objetivos, stack tecnológica e restrições |
| [SECURITY_POLICY.md](./SECURITY_POLICY.md) | **Arquiteto de Software** | Diretrizes de segurança, criptografia, limites de rede e proteção de credenciais |
| [UX_DESIGN_SYSTEM.md](./UX_DESIGN_SYSTEM.md) | **Especialista UX/UI** | Sistema de design GTA VI (Vice City), tokens de cores, tipografia e ergonomia |
| [QA_TEST_STRATEGY.md](./QA_TEST_STRATEGY.md) | **Analista de Qualidade** | Matriz de testes, cenários de borda de rede e critérios de aceitação |
| [DECISIONS/](./DECISIONS/) | **Todos os Agentes** | Registros de Decisões de Arquitetura (ADRs - Architecture Decision Records) |
| [MEETINGS_AND_LOGS.md](./MEETINGS_AND_LOGS.md) | **Líder Orquestrador** | Histórico de decisões, reuniões, status de sprints e backlog ativo |

---

## 📌 Protocolo de Tomada de Decisão

Qualquer decisão significativa que afete a arquitetura, segurança, interface ou qualidade do sistema deve seguir o processo:
1. Proposição pelo agente responsável pelo domínio.
2. Revisão cruzada pelos demais membros da equipe de agentes.
3. Criação de um registro formal no formato **ADR** em `context/DECISIONS/ADR-XXX-<tema>.md`.
4. Registro de log em `context/MEETINGS_AND_LOGS.md`.
5. Validação com o usuário/stakeholder.
