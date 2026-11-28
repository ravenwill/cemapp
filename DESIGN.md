# Design — CEM Peruíbe

Identidade visual do site e da marca CEM Peruíbe. A paleta quente abaixo é a cor oficial do site (desktop, >= 1024px) e da marca; o modo escuro é a mesma identidade com a luz apagada, não um tema azul separado.

Fonte de verdade no código: `lib/theme/app_theme.dart` (`AppColors`).

## Marca

- Tom: acolhedor, terroso, editorial. Café, areia e creme; nada de azul-corporativo nem neon.
- Tipografia do site: Barlow Condensed (títulos, navegação, botões em caixa alta/semibold). App (mobile/tablet): Plus Jakarta Sans.
- Formas: hero em painel arredondado (raio 28), arco como moldura de imagem, barras de tinta nos cantos, faíscas e raios como ornamento leve.

## Paleta da marca (claro / site)

| Papel | Token | Hex |
|---|---|---|
| Fundo da página | background | #FDF0E4 (creme) |
| Superfície | surface | #F7E7D6 |
| Cartão | card | #FFF9F2 |
| Muted | muted | #EBD6C1 |
| Borda | border | #DCC3A9 |
| Painel do hero | siteBg | #E3C9B0 (areia) |
| Texto | foreground / siteInk | #2A2927 (café) |
| Texto secundário | secondary | #4A4038 |
| Texto apagado | mutedForeground | #6B5B4E |
| Destaque / botões | primary / siteAccent | #6F5B4D (cacau) |
| Destaque suave | primarySoft | #EAD5C0 |
| Texto sobre destaque | onPrimary | #FFFFFF |

Regra: a paleta quente vale em todas as telas (desktop, tablet e mobile) no tema claro. O antigo azul-marinho + cobre foi aposentado; o destaque é sempre o cacau (#6F5B4D).

## Modo escuro (todas as telas)

Mesma família de matizes (marrom-quente, ~25–30°), com luminosidade invertida. O destaque passa a ser a areia da marca, que no escuro lê como "luz de vela".

| Papel | Token | Hex |
|---|---|---|
| Fundo da página | background | #1A1613 |
| Superfície | surface | #211B17 |
| Cartão | card | #2A221C |
| Muted | muted | #372D25 |
| Borda | border | #4A3B2F |
| Painel do hero | siteBg | #241C17 |
| Texto | foreground / siteInk | #FDF0E4 (creme) |
| Texto secundário | secondary | #DCC3A9 |
| Texto apagado | mutedForeground | #B8A491 |
| Destaque / botões | primary / siteAccent | #E3C9B0 (areia) |
| Texto sobre destaque | onPrimary | #2A2927 |
| Destaque suave | primarySoft | #3B2F26 |
| Tinta forte (avatar, seleção) | navy | #7A6455 |
| Tinta profunda | navyDeep | #120E0B |
| Tinta suave | navySoft | #30261F |

Semânticas (sucesso, alerta, erro) mantêm os tons já ajustados para fundo escuro e não fazem parte da identidade.

## Princípios

1. Hierarquia por luminosidade e peso, não por cor extra: uma cor de destaque por tela.
2. Contraste: texto principal e secundário >= 4.5:1 sobre fundo e cartão nos dois modos; areia sobre #1A1613 e creme sobre #1A1613 passam com folga.
3. O modo claro no desktop é o "site"; o escuro é o mesmo site à noite. Não introduzir azul no escuro.
4. Nada de preto puro nem branco puro como fundo.
