# ADR-005: Modelo de Governança e Colaboração de Múltiplos Agentes

- **Status**: Aceito
- **Data**: 2026-11-20
- **Decisores**: Líder Orquestrador, Arquiteto de Software, Especialista Flutter, Analista QA, Especialista UX/UI
- **Contexto**: O projeto é complexo e engloba camadas de baixo nível (protocolos de rede, streaming de vídeo C/C++, decodificação de hardware) combinadas com UX avançada, segurança rigorosa e qualidade contínua. Um modelo de agente único tende a perder o foco em detalhes de domínio.

## Decisão
Estabelecer uma equipe de **5 papéis de agentes especializados**:
1. **Líder de Projeto & Orquestrador Geral**: Liderança, priorização, alinhamento com o usuário e manutenção da base de conhecimento `context/`.
2. **Arquiteto de Software & Segurança**: Clean Architecture, segurança da informação e ADRs.
3. **Desenvolvedor Flutter Especialista**: Código Flutter, decodificação via `media_kit`, renderização e performance.
4. **Analista de Qualidade (QA)**: Confiabilidade, suíte de testes e resiliência a falhas de rede.
5. **Especialista em Usabilidade (UX/UI)**: Ergonomia, fluxos de comissionamento sem atrito e consistência GTA VI.

## Protocolo de Trabalho
- Todo avanço significativo deve ter o parecer do especialista do domínio correspondente.
- Todas as decisões estratégicas são persistidas em `context/DECISIONS/`.
- O repositório central no GitHub do usuário é sincronizado continuamente.
