# Horror Game Steam Recreation

[Read in English](README.md)

Uma recriação dentro do Roblox de um jogo de terror industrial da Steam. Você joga como funcionário de uma fábrica estranha, cumprindo seu turno enquanto tenta pagar uma dívida, e aos poucos vai percebendo que aquele lugar não é normal.

O trabalho em si é o centro do jogo. Você aperta parafusos numa esteira, carrega um gerador de manivela, alimenta o triturador e mantém a produção andando, ganhando dinheiro para comprar ferramentas e melhorias na loja e para contratar funcionários. O telefone toca com ligações que fazem a história avançar, as portas de setor liberam áreas novas e existem olhos crescendo nas paredes que você precisa arrancar com um pé de cabra. Personagens como o Tromby e o Tromby Watcher aparecem pelo caminho, conversam com você e somem, e a história tem um final próprio.

O projeto tem menu principal, configurações, legendas para as falas, barra de ferramentas, jumpscares e salvamento automático do progresso. O código do servidor está separado por sistema, a pasta Shared guarda todas as configurações e o cliente cuida das interações, da parte visual e da interface. A pasta ServerStorage também leva o plugin ImportMCP e o pipeline que eu usei para importar e montar o segundo setor do mapa.

É uma recriação feita por fã, para estudo, e não tem ligação com os desenvolvedores originais.

## Como usar

Cada pasta da raiz corresponde a um serviço do Roblox, como Workspace, ReplicatedStorage, ServerScriptService, ServerStorage, StarterGui e StarterPlayer. Leve as pastas para um place vazio mantendo a mesma estrutura, usando o Rojo ou outra ferramenta de sincronização, e aperte Play no Studio. Se quiser que o progresso salve durante os testes no Studio, ative o acesso aos serviços de API nas configurações do jogo.

## Tempo de desenvolvimento

O jogo foi feito em um único dia.

## Licença

GNU General Public License versão 3. O texto completo está no arquivo LICENSE.
