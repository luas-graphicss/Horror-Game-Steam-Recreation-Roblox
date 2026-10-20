local SPOKEN_CHARACTERS_PER_SECOND = 12
local LINE_PAUSE = 0.6
local INTRO = "Intro"
local WARNING = "Warning"
local EXPLANATION = "Explanation"
local PRODUCTIVITY = "Productivity"
local PRAISE = "Praise"
local BLOOD = "Blood"
local SECTOR_TWO = "SectorTwo"
local WATCHER_NOTICE = "WatcherNotice"
local WATCHER_FINALE = "WatcherFinale"
local DEBT_PAID = "DebtPaid"

local PhoneCalls = {
	INTRO = INTRO,
	WARNING = WARNING,
	EXPLANATION = EXPLANATION,
	PRODUCTIVITY = PRODUCTIVITY,
	PRAISE = PRAISE,
	BLOOD = BLOOD,
	SECTOR_TWO = SECTOR_TWO,
	WATCHER_NOTICE = WATCHER_NOTICE,
	WATCHER_FINALE = WATCHER_FINALE,
	DEBT_PAID = DEBT_PAID,
	ORDER = {
		INTRO,
		WARNING,
		EXPLANATION,
		PRODUCTIVITY,
		PRAISE,
		BLOOD,
		SECTOR_TWO,
		WATCHER_NOTICE,
		WATCHER_FINALE,
		DEBT_PAID,
	},
	SCRIPTS = {
		[INTRO] = {
			"OlÃ¡, empregado 4457. Seja bem-vindo.",
			"Seu contrato foi assinado enquanto vocÃª dormia.",
			"Sua dÃ­vida Ã© de 20 mil reais.",
			"NÃ£o pense nisso como uma puniÃ§Ã£o. Pense como um novo comeÃ§o.",
			"A eletricidade Ã© operada manualmente para reduzir custos.",
			"A sua ferramenta estÃ¡ na parede, esperando por vocÃª.",
		},
		[WARNING] = {
			"Se vocÃª ver algo na parede, ignore e continue trabalhando.",
			"NÃ£o hÃ¡ nada na parede.",
		},
		[EXPLANATION] = {
			"Ah, entÃ£o vocÃª viu os olhos na parede.",
			"Eles estÃ£o atrÃ¡s de vocÃª.",
			"Se vocÃª parar de trabalhar, eles vÃ£o atrÃ¡s de vocÃª.",
			"Mas, se vocÃª olhar pra ele, ele congela. Acho que eles ficam incomodados.",
			"Tem um pÃ© de cabra no setor 2. AÃ­ vocÃª poderia tirar esses olhos malditos.",
			"Mas, atÃ© lÃ¡, nÃ£o seja pego.",
		},
		[PRODUCTIVITY] = {
			"Recebemos as estatÃ­sticas da sua produtividade.",
			"Por favor, acelere o ritmo utilizando os itens fornecidos.",
			"E nÃ£o se preocupe com o valor.",
			"Parece pequeno, mas multiplicando pelo resto da sua vida se torna razoÃ¡vel.",
		},
		[PRAISE] = {
			"VocÃª estÃ¡ trabalhando muito bem.",
			"A maioria das pessoas que vÃªm pra cÃ¡ ficam sentadas no escuro esperando alguÃ©m chegar.",
			"NinguÃ©m aparece.",
			"Nunca.",
		},
		[BLOOD] = {
			"O RH me disse que vocÃª precisa de sangue para ser mais produtivo.",
			"Instalamos tudo o que Ã© necessÃ¡rio na sala ao lado.",
			"Mas vocÃª sÃ³ vai poder entrar lÃ¡ quando provar o seu valor.",
		},
		[SECTOR_TWO] = {
			"Acesso ao setor 2 liberado.",
			"Mas, para entrar, vocÃª precisa pagar.",
			"Nem todos pagam para ir mais fundo em uma fÃ¡brica.",
			"VocÃª precisa pagar pelas ferramentas.",
			"LÃ¡ vocÃª vai encontrar a linha orgÃ¢nica.",
			"A ferramenta nÃ£o quebra. NÃ³s aprendemos essa liÃ§Ã£o.",
		},
		[WATCHER_NOTICE] = {
			"SaÃ­da estÃ¡vel sem entrada manual. NotÃ¡vel.",
			"VocÃª provavelmente estÃ¡ se perguntando como alguÃ©m sai daÃ­.",
			"Essa Ã© a pergunta certa.",
			"NÃ£o cabe a nÃ³s respondÃª-la.",
		},
		[WATCHER_FINALE] = {
			"Cinco posiÃ§Ãµes liberadas.",
			"VocÃª liberou a alavanca.",
			"Queremos deixar claro que nÃ£o pedimos nada a vocÃª. Apenas tornamos isso lucrativo.",
			"Siga em frente, empregado.",
		},
		[DEBT_PAID] = {
			"Empregado, parabÃ©ns. VocÃª pagou a sua dÃ­vida.",
			"Eu vou ser direto com vocÃª, porque vocÃª merece.",
			"NinguÃ©m sai desse lugar.",
			"Isso nÃ£o Ã© uma ameaÃ§a. Ã estatÃ­stica.",
			"A porta dos fundos estÃ¡ aberta essa noite e fecha amanhÃ£ Ã s seis.",
			"VÃ¡ pra casa e descanse, empregado.",
		},
	} :: { [string]: { string } },
}

function PhoneCalls.characterCount(text: string): number
	return utf8.len(text) or #text
end

function PhoneCalls.lineDuration(line: string): number
	return PhoneCalls.characterCount(line) / SPOKEN_CHARACTERS_PER_SECOND + LINE_PAUSE
end

function PhoneCalls.duration(callId: string): number
	local total = 0
	for _, line in PhoneCalls.SCRIPTS[callId] do
		total += PhoneCalls.lineDuration(line)
	end
	return total
end

return PhoneCalls
