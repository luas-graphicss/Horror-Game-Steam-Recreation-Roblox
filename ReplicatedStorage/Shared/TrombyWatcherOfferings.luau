export type Conversation = {
	lines: { string },
	gratitude: { string },
}

export type Offering = {
	biomassCost: number,
	conversation: Conversation,
}

local OFFERINGS: { Offering } = {
	{
		biomassCost = 8,
		conversation = {
			lines = {
				"VocÃª me encontrou! Mas eu nÃ£o estava me escondendo.",
				"Eu parei de oferecer minha ajuda, nÃ£o adiantava para ninguÃ©m mesmo, nem para vocÃª, nem para mim.",
				"Agora eu peÃ§o, quero biomassa. O triturador a produz com o que sobrou dos funcionÃ¡rios.",
				"Isso nÃ£o Ã© uma ordem, vocÃª tem permissÃ£o para recusar, mas eu preciso de uma contribuiÃ§Ã£o inicial.",
				"VocÃª nÃ£o tem nada a perder, nada que vocÃª jÃ¡ nÃ£o tenha perdido.",
			},
			gratitude = {
				"Obrigado, essa Ã© a primeira coisa que entra aqui sem preencher um formulÃ¡rio.",
			},
		},
	},
	{
		biomassCost = 16,
		conversation = {
			lines = {
				"Novamente! Eu sei o quanto isso te custa, mas sÃ£o mÃ¡quinas que vocÃª nÃ£o vai atualizar.",
			},
			gratitude = {
				"Eu posso sentir a diferenÃ§a! VocÃª vai produzir mais, esse Ã© o seu trabalho.",
			},
		},
	},
	{
		biomassCost = 28,
		conversation = {
			lines = {
				"VocÃª hesita menos do que no comeÃ§o. Estou anotando isso.",
				"NÃ£o Ã© repreensÃ£o. Muito pelo contrÃ¡rio.",
			},
			gratitude = {
				"Agora estou entendendo esse lugar. A fÃ¡brica nÃ£o produz nada, ela consome.",
				"VocÃª Ã© um estÃ¡gio nisso.",
			},
		},
	},
	{
		biomassCost = 44,
		conversation = {
			lines = {
				"Eu preciso de mais! Eu nÃ£o sei o quÃª ainda. Nem vocÃª sabe.",
			},
			gratitude = {
				"AlguÃ©m aqui decide quem Ã© Ãºtil. Ele tem um escritÃ³rio, uma janela, um telefone.",
				"Eu nunca tive um escritÃ³rio.",
			},
		},
	},
	{
		biomassCost = 64,
		conversation = {
			lines = {
				"Essa serÃ¡ a Ãºltima vez. Depois disso, eu nÃ£o precisarei mais de vocÃª, e vocÃª nÃ£o precisarÃ¡ mais apertar nada.",
				"Pense bem. Podemos sair ganhando.",
			},
			gratitude = {
				"Isso serÃ¡ suficiente. NÃ£o me siga, esse lugar nÃ£o Ã© para vocÃª.",
				"Agora, quando tocar, atenda. Ele estarÃ¡ te esperando.",
			},
		},
	},
}

local TrombyWatcherOfferings = {}

function TrombyWatcherOfferings.at(contributions: number): Offering?
	return OFFERINGS[contributions + 1]
end

function TrombyWatcherOfferings.count(): number
	return #OFFERINGS
end

function TrombyWatcherOfferings.isFulfilled(contributions: number): boolean
	return contributions >= #OFFERINGS
end

return TrombyWatcherOfferings
