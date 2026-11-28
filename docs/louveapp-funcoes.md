# Mapa de funções do LouveApp (referência para o módulo Louvor do CEMAPP)

Levantado pela interface visível (versão web mobile), sem copiar código, marcas ou conteúdo.

## Navegação (barra inferior, 5 abas)
1. **Início** — Ministérios (cards com nº de escalas, músicas e membros), Avisos (em destaque), Minhas Escalas (próximas, com status de confirmação), Aniversariantes do mês, atalho "Mais tocadas".
2. **Escalas** — abas Próximas / Anteriores; "Panorama de escalas"; filtro e alternar visualização; cartão por data (dia, hora, nome do culto, avatares dos escalados, status Pendente/Confirmado, nº de músicas).
3. **Repertório** — abas Músicas / Pastas / Artistas; busca; item com capa, título, artista, classificação e tom; atalhos de letra, cifra, áudio e vídeo.
4. **Mensagens** — chat do ministério (texto, emojis, data/hora, avatar).
5. **Ministério** — abas Informações / Membros (x/limite); Equipes, Funções, Classificações; Integrações só para administradores (Holyrics, tokens de API).

## Detalhe de Escala
- Abas: Detalhes, Músicas (qtd), Participantes (confirmados/total), Roteiro (itens do culto).
- Ações: confirmar/recusar presença, Compartilhar, Confirmados (x de y), Histórico de alterações, Google Agenda, Comentários.

## Detalhe de Música
- Capa, título, álbum, artista; links externos (Spotify, Letras, Cifra Club, YouTube, Deezer, Amazon Music, Apple Music, SoundCloud).
- Versão (Original/outras) com Tom, BPM, Duração, Classificações.
- Referências: Letra, Cifra, Áudio, Vídeo (URLs).

## Modelo de dados sugerido (Supabase / Postgres)
- `profiles` (id = auth.users.id, nome, foto, nascimento)
- `user_features` (user_id, feature) — o que o Master libera
- `ministries`, `ministry_members` (ministry_id, user_id, status)
- `teams`, `roles` (funções), `classifications`
- `songs` (título, artista, álbum, capa), `song_versions` (tom, bpm, duração), `song_links` (tipo, url), `folders`
- `schedules` (ministry_id, nome, data/hora), `schedule_members` (schedule_id, user_id, role_id, status: pendente/confirmado/recusado), `schedule_songs` (ordem, version_id), `schedule_items` (roteiro), `schedule_history`, `schedule_comments`
- `announcements`, `messages`
- RLS: leitura por membros do ministério; escrita de escalas/músicas só por líder/Master.

## Decisões
- Letras e cifras: guardar só links externos e conteúdo próprio da igreja (direitos autorais).
- Login Google via Supabase Auth; permissões em `user_features`.
