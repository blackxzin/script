-- ============================================================
--  Elite Automation Framework :: Systems.FruitDatabase
--  Arquitetura de Dados de Itens e Raridades (GPO)
-- ============================================================

-- [[ NOTA TÉCNICA ]]
-- O uso de normalização de strings permite que o sistema identifique 
-- a fruta mesmo que o nome no Workspace venha com erros de digitação, 
-- espaços extras ou sufixos como "no Mi".

local FruitDatabase = {}

-- ─── [1] CONFIGURAÇÕES DE RARIDADE ───────────────────────────
FruitDatabase.RarityPriority = {
	Common    = 1,
	Rare      = 2,
	Legendary = 4,
	Mythical  = 5,
}

-- ─── [2] DATABASE DE ITENS (Otimizada) ───────────────────────
-- Estrutura: [ID] = { Dados }
local DATA = {
	-- COMUNS
	Suke       = { name = "Suke Suke no Mi", fullName = "Suke Suke no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 5000   },
	Spin       = { name = "Guru Guru no Mi", fullName = "Guru Guru no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 7500   },
	Kilo       = { name = "Kilo Kilo no Mi", fullName = "Kilo Kilo no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 10000  },

	-- RARAS
	Bomu       = { name = "Bomu Bomu no Mi", fullName = "Bomu Bomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 150000 },
	Bari       = { name = "Bari Bari no Mi", fullName = "Bari Bari no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 180000 },
	Mero       = { name = "Mero Mero no Mi", fullName = "Mero Mero no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 220000 },
	Gomu       = { name = "Gomu Gomu no Mi", fullName = "Gomu Gomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 250000 },
	Horu       = { name = "Horu Horu no Mi", fullName = "Horu Horu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 200000 },

	-- LENDÁRIAS
	Pika       = { name = "Pika Pika no Mi", fullName = "Pika Pika no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15),  value = 2500000 },
	Magu       = { name = "Magu Magu no Mi", fullName = "Magu Magu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 126, 34),  value = 2400000 },
	Mera       = { name = "Mera Mera no Mi", fullName = "Mera Mera no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 80, 25),   value = 2200000 },
	Goro       = { name = "Goro Goro no Mi", fullName = "Goro Goro no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 215, 0),   value = 2100000 },
	Hie        = { name = "Hie Hie no Mi",   fullName = "Hie Hie no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(130, 210, 255), value = 1800000 },
	Ito        = { name = "Ito Ito no Mi",   fullName = "Ito Ito no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(233, 30, 99),   value = 1600000 },
	Suna       = { name = "Suna Suna no Mi", fullName = "Suna Suna no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(218, 165, 32),  value = 1500000 },
	Zushi      = { name = "Zushi Zushi no Mi", fullName = "Zushi Zushi no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(155, 89, 182), value = 1700000 },
	Paw        = { name = "Nikyu Nikyu no Mi", fullName = "Nikyu Nikyu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 105, 180), value = 1750000 },
	Kage       = { name = "Kage Kage no Mi", fullName = "Kage Kage no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(75, 0, 130),    value = 1900000 },
	Yuki       = { name = "Yuki Yuki no Mi", fullName = "Yuki Yuki no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(200, 240, 255), value = 1850000 },

	-- MÍTICAS
	Mochi      = { name = "Mochi Mochi no Mi", fullName = "Mochi Mochi no Mi", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 5000000 },
	Tori       = { name = "Tori Tori no Mi",   fullName = "Tori Tori no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(0, 240, 255),   value = 4500000 },
	Ope        = { name = "Ope Ope no Mi",     fullName = "Ope Ope no Mi",     rarity = "Mythical", priority = 5, color = Color3.fromRGB(142, 68, 173),  value = 4800000 },
	Venom      = { name = "Doku Doku no Mi",   fullName = "Doku Doku no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(186, 85, 211),  value = 4200000 },
	Buddha     = { name = "Hito Hito: Daibutsu", fullName = "Hito Hito no Mi, Model: Daibutsu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 215, 0), value = 4000000 },
	Dragon     = { name = "Uo Uo: Seiryu",     fullName = "Uo Uo no Mi, Model: Seiryu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(46, 204, 113),  value = 5500000 },

	-- ITENS ESPECIAIS
	MythicalChest  = { name = "Mythical Chest",  fullName = "Mythical Fruit Chest",  rarity = "Mythical",  priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 3500000 },
	LegendaryChest = { name = "Legendary Chest", fullName = "Legendary Fruit Chest", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15), value = 1500000 },
	RareChest      = { name = "Rare Chest",      fullName = "Rare Fruit Chest",      rarity = "Rare",      priority = 3, color = Color3.fromRGB(52, 152, 219),  value = 500000  },
	DarkRoot       = { name = "Dark Root",       fullName = "Dark Root",             rarity = "Rare",      priority = 3, color = Color3.fromRGB(110, 50, 160),  value = 250000  },
	SPReset        = { name = "SP Reset Root",   fullName = "SP Reset Root",         rarity = "Rare",      priority = 3, color = Color3.fromRGB(46, 204, 113),  value = 150000  },
}

-- ─── [3] MÉTODOS DE BUSCA (Matching Engine) ──────────────────

-- Normalização de strings para busca fuzzy (remove espaços, traços e sufixos)
local function normalize(str)
	if not str then return "" end
	return str:lower()
		:gsub("%s*no%s*mi", "") -- Remove "no Mi"
		:gsub("[_%-%s]", "")     -- Remove caracteres especiais e espaços
end

-- Busca rápida por ID ou Nome Exato
function FruitDatabase:Get(name)
	if not name or type(name) ~= "string" then return nil end

	-- 1. Match Direto (O mais rápido)
	if DATA[name] then return DATA[name] end

	-- 2. Match por Nome Normalizado (Para casos como "Mera-Mera" vs "MeraMera")
	local targetNorm = normalize(name)
	
	for key, info in pairs(DATA) do
		-- Teste o ID normalizado
		if normalize(key) == targetNorm then
			return info
		end
		
		-- Teste o Nome Completo normalizado
		if info.name and normalize(info.name) == targetNorm then
			return info
		end
		
		-- Teste o FullName (para casos complexos)
		if info.fullName and normalize(info.fullName) == targetNorm then
			return info
		end
		
		-- 3. Match Parcial (Fallback para nomes incompletos como "Mera")
		if targetNorm:len() >= 4 then -- Evita falsos positivos com nomes muito curtos
			if targetNorm:find(normalize(key), 1, true) or 
			   (info.name and targetNorm:find(normalize(info.name), 1, true)) then
				return info
			end
		end
	end

	return nil
end

-- Verifica se a raridade atende ao requisito mínimo
function FruitDatabase:MeetsMinRarity(fruitName, minRarity)
	local data = self:Get(fruitName)
	if not data then return false end
	
	local minPriority = self.RarityPriority[minRarity] or 1
	return data.priority >= minPriority
end

-- ─── [4] EXPORTAÇÃO ──────────────────────────────────────────

-- Expõe os dados junto com os métodos de busca do módulo.
-- Retornar DATA aqui descartaria Get/MeetsMinRarity e quebraria o FruitTracker.
for k, v in pairs(DATA) do
    FruitDatabase[k] = v
end

return FruitDatabase
