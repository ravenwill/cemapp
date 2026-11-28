# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack
Flutter (web/PWA publicado em GitHub Pages + Android), Supabase (Postgres, Auth com Google, RLS), supabase_flutter, google_fonts, shared_preferences, url_launcher. Código em `C:\dev\cemapp\lib`; deploy com `deploy-web.ps1`.

## Users
Todos os membros da CEM Peruíbe: membros comuns, líderes de ministério, time de louvor, mídia e demais equipes. Uso majoritário no celular, em casa, a caminho ou no culto. Idades variadas. O Master (administrador) controla quais módulos cada usuário vê.

## Product Purpose
App da igreja CEM Peruíbe: concentra avisos, agenda de cultos e eventos, pedidos de oração, pedidos de Yakisoba, aniversariantes e o módulo de Louvor (escalas, equipe, repertório e cifras, inspirado no LouveApp). Sucesso: a igreja deixa de depender de mensagens soltas no WhatsApp e cada pessoa acha rapidamente o que lhe diz respeito.

## Positioning
Tudo da igreja em um só app, com o louvor no estilo LouveApp, login Google e menu por permissões controladas pelo Master.

## Operating Context
- Login somente com Google; durante o teste, o consentimento OAuth está em modo "Testando" (só e-mails de teste entram).
- Papéis: Master (`is_master`), líder de ministério (`ministry_members.is_leader`), membro; módulos liberados por usuário (avisos e agenda por padrão).
- Louvor: escalas por culto com equipe (pessoas com ou sem conta) e funções, repertório com versões e cifras (ChordPro, modos Cifra/Letra/Smart, transposição). Líderes e Master criam e editam escalas.
- Cultos recorrentes: domingo 19h e quinta (oração) 20h.

## Capabilities and Constraints
- Idioma e terminologia: português do Brasil; "escala", "equipe", "repertório", "cifra", "Louvor", "Yakisoba".
- Sem cópia em massa do Cifra Club; cifras são cadastradas pela equipe.
- Fonte de dados: Supabase (projeto `ifzpueystgpzjhuprlaw`), com políticas RLS e função `can_manage()` para Master/líderes.
- Publicação web em https://ravenwill.github.io/cemapp/ e instalável como PWA; APK apenas quando solicitado.

## Brand Commitments
Nome: CEMAPP (CEM Peruíbe). Tom acolhedor e direto ("Paz do Senhor, ..."). Identidade visual já estabelecida pelo projeto (azul-marinho e cobre, tema claro e escuro); decisões visuais não são registradas aqui.

## Evidence on Hand
Dados reais cadastrados: escalas de teste e do Culto de Oração de 19/11/2026, equipe do louvor, repertório com cifras. Sem depoimentos, métricas ou números de uso; não inventar.

## Product Principles
1. Mobile primeiro: o que a pessoa precisa em segundos fica a um toque.
2. Cada pessoa vê só os módulos que importam para ela, conforme o Master define.
3. O louvor serve o momento do culto: cifra legível, troca de música rápida, pouca interface atrapalhando.
4. Informação da igreja em um só lugar, sempre atualizada.

## Accessibility & Inclusion
Público de idades variadas: texto legível, contraste alto, alvos de toque confortáveis, funciona em tema claro e escuro.
