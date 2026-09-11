-- ============================================================
--  Elite Automation Framework :: Systems.FruitDatabase
--  Base de dados de Frutas e Baús do Grand Piece Online (GPO)
--  com raridades, valores em Peli, aliases e cores para UI.
-- ============================================================

--[[
	Raridades canônicas de GPO:
	  Common    → Cinza (Suke, Spin, Kilo)
	  Rare      → Azul (Bomu, Bari, Mero, Gomu, Horu)
	  Legendary → Laranja/Dourado (Pika, Magu, Mera, Goro, Hie, Ito, Suna, Zushi, Paw, Kage, Yuki)
	  Mythical  → Vermelho/Magenta (Mochi, Tori, Ope, Venom, Buddha, Dragon)
	  Special   → Baús de Frutas e Raízes (Dark Root, SP Reset)

	Priority: quanto maior, mais urgente para coletar.
]]

local FruitDatabase = {

	-- ─── COMUNS ───────────────────────────────────────────
	Suke       = { name = "Suke Suke no Mi", fullName = "Suke Suke no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 5000   },
	Spin       = { name = "Guru Guru no Mi", fullName = "Guru Guru no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 7500   },
	Guru       = { name = "Guru Guru no Mi", fullName = "Guru Guru no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 7500   },
	Kilo       = { name = "Kilo Kilo no Mi", fullName = "Kilo Kilo no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 10000  },

	-- ─── RARAS ────────────────────────────────────────────
	Bomu       = { name = "Bomu Bomu no Mi", fullName = "Bomu Bomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 150000 },
	Bomb       = { name = "Bomu Bomu no Mi", fullName = "Bomu Bomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 150000 },
	Bari       = { name = "Bari Bari no Mi", fullName = "Bari Bari no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 180000 },
	Barrier    = { name = "Bari Bari no Mi", fullName = "Bari Bari no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 180000 },
	Mero       = { name = "Mero Mero no Mi", fullName = "Mero Mero no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 220000 },
	Love       = { name = "Mero Mero no Mi", fullName = "Mero Mero no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 220000 },
	Gomu       = { name = "Gomu Gomu no Mi", fullName = "Gomu Gomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 250000 },
	Rubber     = { name = "Gomu Gomu no Mi", fullName = "Gomu Gomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 250000 },
	Horu       = { name = "Horu Horu no Mi", fullName = "Horu Horu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 200000 },

	-- ─── LENDÁRIAS (GPO LEGENDARY LOGIAS & PARAMECIAS) ────
	Pika       = { name = "Pika Pika no Mi", fullName = "Pika Pika no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15),  value = 2500000 },
	Light      = { name = "Pika Pika no Mi", fullName = "Pika Pika no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15),  value = 2500000 },
	Magu       = { name = "Magu Magu no Mi", fullName = "Magu Magu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 126, 34),  value = 2400000 },
	Magma      = { name = "Magu Magu no Mi", fullName = "Magu Magu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 126, 34),  value = 2400000 },
	Mera       = { name = "Mera Mera no Mi", fullName = "Mera Mera no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 80, 25),   value = 2200000 },
	Flame      = { name = "Mera Mera no Mi", fullName = "Mera Mera no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 80, 25),   value = 2200000 },
	Goro       = { name = "Goro Goro no Mi", fullName = "Goro Goro no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 215, 0),   value = 2100000 },
	Rumble     = { name = "Goro Goro no Mi", fullName = "Goro Goro no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 215, 0),   value = 2100000 },
	Hie        = { name = "Hie Hie no Mi",   fullName = "Hie Hie no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(130, 210, 255), value = 1800000 },
	Ice        = { name = "Hie Hie no Mi",   fullName = "Hie Hie no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(130, 210, 255), value = 1800000 },
	Ito        = { name = "Ito Ito no Mi",   fullName = "Ito Ito no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(233, 30, 99),   value = 1600000 },
	String     = { name = "Ito Ito no Mi",   fullName = "Ito Ito no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(233, 30, 99),   value = 1600000 },
	Suna       = { name = "Suna Suna no Mi", fullName = "Suna Suna no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(218, 165, 32),  value = 1500000 },
	Sand       = { name = "Suna Suna no Mi", fullName = "Suna Suna no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(218, 165, 32),  value = 1500000 },
	Zushi      = { name = "Zushi Zushi no Mi", fullName = "Zushi Zushi no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(155, 89, 182), value = 1700000 },
	Gravity    = { name = "Zushi Zushi no Mi", fullName = "Zushi Zushi no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(155, 89, 182), value = 1700000 },
	Paw        = { name = "Nikyu Nikyu no Mi", fullName = "Nikyu Nikyu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 105, 180), value = 1750000 },
	Nikyu      = { name = "Nikyu Nikyu no Mi", fullName = "Nikyu Nikyu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 105, 180), value = 1750000 },
	Kage       = { name = "Kage Kage no Mi", fullName = "Kage Kage no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(75, 0, 130),    value = 1900000 },
	Shadow     = { name = "Kage Kage no Mi", fullName = "Kage Kage no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(75, 0, 130),    value = 1900000 },
	Yuki       = { name = "Yuki Yuki no Mi", fullName = "Yuki Yuki no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(200, 240, 255), value = 1850000 },
	Snow       = { name = "Yuki Yuki no Mi", fullName = "Yuki Yuki no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(200, 240, 255), value = 1850000 },

	-- ─── MÍTICAS (GPO MYTHICALS) ──────────────────────────
	Mochi      = { name = "Mochi Mochi no Mi", fullName = "Mochi Mochi no Mi", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 5000000 },
	Tori       = { name = "Tori Tori no Mi",   fullName = "Tori Tori no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(0, 240, 255),   value = 4500000 },
	Phoenix    = { name = "Tori Tori no Mi",   fullName = "Tori Tori no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(0, 240, 255),   value = 4500000 },
	Ope        = { name = "Ope Ope no Mi",     fullName = "Ope Ope no Mi",     rarity = "Mythical", priority = 5, color = Color3.fromRGB(142, 68, 173),  value = 4800000 },
	Venom      = { name = "Doku Doku no Mi",   fullName = "Doku Doku no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(186, 85, 211),  value = 4200000 },
	Doku       = { name = "Doku Doku no Mi",   fullName = "Doku Doku no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(186, 85, 211),  value = 4200000 },
	Buddha     = { name = "Hito Hito: Daibutsu", fullName = "Hito Hito no Mi, Model: Daibutsu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 215, 0), value = 4000000 },
	Daibutsu   = { name = "Hito Hito: Daibutsu", fullName = "Hito Hito no Mi, Model: Daibutsu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 215, 0), value = 4000000 },
	Dragon     = { name = "Uo Uo: Seiryu",     fullName = "Uo Uo no Mi, Model: Seiryu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(46, 204, 113),  value = 5500000 },

	-- ─── BAÚS DE FRUTA E ITENS ESPECIAIS DE GPO ───────────
	MythicalChest  = { name = "Mythical Chest",  fullName = "Mythical Fruit Chest",  rarity = "Mythical",  priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 3500000 },
	LegendaryChest = { name = "Legendary Chest", fullName = "Legendary Fruit Chest", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15), value = 1500000 },
	RareChest      = { name = "Rare Chest",      fullName = "Rare Fruit Chest",      rarity = "Rare",      priority = 3, color = Color3.fromRGB(52, 152, 219),  value = 500000  },
	DarkRoot       = { name = "Dark Root",       fullName = "Dark Root",             rarity = "Rare",      priority = 3, color = Color3.fromRGB(110, 50, 160),  value = 250000  },
	SPReset        = { name = "SP Reset Root",   fullName = "SP Reset Root",         rarity = "Rare",      priority = 3, color = Color3.fromRGB(46, 204, 113),  value = 150000  },

}

-- ─── Tabela de prioridade mínima por string ─────────────────
FruitDatabase.RarityPriority = {
	Common    = 1,
	Rare      = 2,
	Legendary = 4,
	Mythical  = 5,
}

-- ─── Helpers ─────────────────────────────────────────────────

-- Normaliza strings para matching flexível (remove "no Mi", traços e espaços)
local function normalizeKey(str)
	return str:lower()
		:gsub("%s*no%s*mi", "")
		:gsub("[_%-%s]", "")
end

-- Retorna os dados de uma fruta pelo nome ou variante
function FruitDatabase:Get(name)
	if not name or type(name) ~= "string" then return nil end

	-- Teste direto exato
	if self[name] then return self[name] end

	-- Teste case-insensitive direto
	local lower = name:lower()
	for k, v in pairs(self) do
		if type(k) == "string" and type(v) == "table" and k:lower() == lower then
			return v
		end
	end

	-- Teste normalizado (cobre "Mera-Mera", "Mera Mera no Mi", "Pika_Fruit", etc.)
	local normTarget = normalizeKey(name)
	for k, v in pairs(self) do
		if type(k) == "string" and type(v) == "table" and v.rarity then
			local normK = normalizeKey(k)
			if normTarget:find(normK, 1, true) or normK:find(normTarget, 1, true) then
				return v
			end
			if v.name and normalizeKey(v.name):find(normTarget, 1, true) then
				return v
			end
			if v.fullName and normalizeKey(v.fullName):find(normTarget, 1, true) then
				return v
			end
		end
	end

	return nil
end

-- Verifica se a raridade da fruta atende ao mínimo configurado
function FruitDatabase:MeetsMinRarity(fruitName, minRarity)
	local data    = self:Get(fruitName)
	if not data then return false end
	local minPrio = self.RarityPriority[minRarity] or 1
	return data.priority >= minPrio
end

return FruitDatabase
