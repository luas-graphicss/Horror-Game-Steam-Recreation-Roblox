local Money = require(script.Parent.Money)

export type Screen = {
	title: string,
	body: string,
}

local CLIP = "Clip"
local DEBT = "Debt"

return {
	CLIP = CLIP,
	DEBT = DEBT,
	FAREWELL = "Obrigado por jogar.",
	KICK_MESSAGE = "Fim de jogo. Obrigado por jogar A Empresa estÃ¡ vigiando.",
	SCREENS = {
		[CLIP] = {
			title = "ParabÃ©ns",
			body = "VocÃª chegou como o empregado 4457, com uma dÃ­vida de 20 mil reais e um contrato assinado enquanto dormia. Apertou parafusos, girou a manivela no escuro e aprendeu a encarar os olhos nas paredes. No setor 2, Clip pediu aquilo que a fÃ¡brica consome, e vocÃª entregou cinco vezes. A alavanca foi liberada. AlguÃ©m novo ocupa o escritÃ³rio agora, e a linha segue rodando sem precisar de vocÃª.",
		},
		[DEBT] = {
			title = string.format("Balance: %s$", Money.format(0)),
			body = "Vinte mil reais, pagos parafuso por parafuso, coraÃ§Ã£o por coraÃ§Ã£o. A empresa cumpriu a parte dela: a dÃ­vida acabou. NinguÃ©m sai desse lugar, disseram ao telefone. Mas a porta dos fundos ficou aberta por uma noite, e vocÃª nÃ£o esperou dar seis horas. LÃ¡ fora ainda estava escuro. Pela primeira vez, ninguÃ©m estava vigiando.",
		},
	} :: { [string]: Screen },
}
