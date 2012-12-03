local ezInterrupt = LibStub("AceAddon-3.0"):NewAddon("ezInterrupt", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("ezInterrupt")
local LSM = LibStub("LibSharedMedia-3.0")
LSM:Register("sound", L["Shay's Bell"], [[Sound\Spells\ShaysBell.ogg]])
LSM:Register("sound", L["Simon Chime"], [[Sound\Doodad\SimonGame_LargeBlueTree.ogg]])
LSM:Register("sound", L["Humm"], [[Sound\Spells\SimonGame_Visual_GameStart.ogg]])
LSM:Register("sound", L["Short Circuit"], [[Sound\Spells\SimonGame_Visual_BadPress.ogg]])
LSM:Register("sound", L["ezInterrupt: Beep"], [[Interface\Addons\ezInterrupt\media\beep.ogg]])
LSM:Register("sound", L["ezInterrupt: Ding"], [[Interface\Addons\ezInterrupt\media\ding.ogg]])
LSM:Register("sound", L["ezInterrupt: Chime"], [[Interface\Addons\ezInterrupt\media\chime.ogg]])
LSM:Register("sound", L["Tech Gun"], [[Sound\Spells\SPELL_ShootTechGun_Cast_05.ogg]])

local gsub = gsub
local pairs = pairs
local bit_and = bit.band
local GetSpellCooldown = GetSpellCooldown
local UnitCanAttack = UnitCanAttack
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local IsUsableSpell = IsUsableSpell
local outputChannel
local lastSoundAlert = 0
local latencyOffset = 0.1
local class
local CooldownTracker = CreateFrame("Frame")
local msgTags = {}
local TRIGGER_UNIT_BITMASK
local ImmunityAuras = { 
	--> Only add auras that cause spells to be correctly recognized as uninterruptible for their duration
	[95537] = true, -- Shield of Light (Atramedes trash)
	[80747] = true, -- Shield of Light (Atramedes trash)
	[65874] = true, -- Shield of Darkness (Eydis Darkbane)
	[67256] = true, -- Shield of Darkness (Eydis Darkbane)
	[67257] = true, -- Shield of Darkness (Eydis Darkbane)
	[67258] = true, -- Shield of Darkness (Eydis Darkbane)
	[67260] = true, -- Shield of Lights (Fjola Lightbane)
	[65858] = true, -- Shield of Lights (Fjola Lightbane)
	[67259] = true, -- Shield of Lights (Fjola Lightbane)
	[67261] = true, -- Shield of Lights (Fjola Lightbane)
	[36815] = true, -- Shock Barrier (Kael'Thas)
	[46165] = true, -- Shock Barrier (Kael'Thas)
	[92512] = true, -- Aegis of Flame (Ignacious)
	[82631] = true, -- Aegis of Flame (Ignacious)
	[92513] = true, -- Aegis of Flame (Ignacious)
	[92514] = true, -- Aegis of Flame (Ignacious)
	[93335] = true, -- Icy Shroud (Ascendant Council trash)
}
local defaults = {
	profile = {
		enableAddon = true,
		enableAnnouncing = true,
		enableCastAlerts = true,
		enableSound = true,
		enableIcon = true,
		enableFlash = false,
		whisperRecipient = nil,
		customChannel = nil,
		customMsg = L["Interrupted [spell]"],
		useSystem = true,
		useSay = true,
		useParty = false,
		useRaid = false,
		useWhisper = false,
		useCustomChannel = false,
		activeInRaid = true,
		activeInParty = true,
		activeInBg = true,
		activeInArena = true,
		activeInWorld = true,
		soundFile = L["ezInterrupt: Ding"],
		triggerUnit = "target",
		filterMode = 1, -- 1 means disabled, 2 means filter through blackList, 3 means filter through whitelist 
		whiteList = {},
		blackList = {},
		iconPos = {"CENTER",nil,"CENTER",0,0},
		iconSize = 44,
		iconAlpha = 1,
		iconBlending = "BLEND",
		flashAlpha = 0.5,
		flashDuration = 0.4,
		interruptSettings = {
			-- Warrior
			[6552]	= {userenabled = true,  id = 6552,  sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Pummel			
			[102060] = {userenabled = true,  id = 102060,  sound = "ezInterrupt: Chime", rgb = {1, 0, 0}},		-- Disrupting Shout!
			-- Druid
			[80964]	= {userenabled = true,  id = 80964, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Skull Bash (Bear)
			[80965]	= {userenabled = true,  id = 80965, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Skull Bash (Cat)
			-- Rogue
			[1766]	= {userenabled = true,  id = 1766,  sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Kick
			[26679]	= {userenabled = false, id = 26679, sound = "ezInterrupt: Chime", rgb = {0.5, 1, 0.28}},	-- Deadly Throw
			-- Paladin
			[96231]	= {userenabled = true,  id = 96231, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Rebuke
			[31935]	= {userenabled = false, id = 31935, sound = "ezInterrupt: Chime", rgb = {0.5, 1, 0.28}},	-- Avenger's Shield
			-- Deathknight
			[47528]	= {userenabled = true,  id = 47528, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Mind Freeze
			[47476]	= {userenabled = false, id = 47476, sound = "ezInterrupt: Chime", rgb = {0.5, 1, 0.28}},	-- Strangulate
			-- [91802]	= {userenabled = false, id = 91802, sound = "ezInterrupt: Beep", rgb = {0.9, 0.9, 0}},	-- Shambling Rush, not  yet supported
			-- Mage
			[2139]	= {userenabled = true,  id = 2139,  sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Counterspell
			-- Warlock
			[19647]	= {userenabled = true,  id = 19647, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Spell Lock
			-- Shaman
			[57994]	= {userenabled = true,  id = 57994, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Wind Shear
			-- Hunter
			[34490]	= {userenabled = true,  id = 34490, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Silencing Shot
			[26090]	= {userenabled = false, id = 26090, sound = "ezInterrupt: Chime", rgb = {0.5, 1, 0.28}},	-- Pummel (Gorilla)
			[50479]	= {userenabled = false, id = 50479, sound = "ezInterrupt: Chime", rgb = {0.5, 1, 0.28}},	-- Nether Shock
			[50318]	= {userenabled = false, id = 50318, sound = "ezInterrupt: Chime", rgb = {0.5, 1, 0.28}},	-- Serenity Dust
			-- Priest
			[15487]	= {userenabled = true,  id = 15487, sound = "ezInterrupt: Ding", rgb = {1, 0, 0}},		-- Silence
			-- Racial
			[28730]	= {userenabled = false, id = 28730, sound = "ezInterrupt: Beep",		 rgb = {0.1, 0.78, 1}},	-- Arcane Torrent (Mana)
			[50613]	= {userenabled = false, id = 50613, sound = "ezInterrupt: Beep",		 rgb = {0.1, 0.78, 1}},	-- Arcane Torrent (RP)
			[80483]	= {userenabled = false, id = 80483, sound = "ezInterrupt: Beep",		 rgb = {0.1, 0.78, 1}},	-- Arcane Torrent (Focus)
			[25046]	= {userenabled = false, id = 25046, sound = "ezInterrupt: Beep",		 rgb = {0.1, 0.78, 1}},	-- Arcane Torrent (Energy)
			[69179]	= {userenabled = false, id = 69179, sound = "ezInterrupt: Beep",		 rgb = {0.1, 0.78, 1}},	-- Arcane Torrent (Rage)
		}
	}
}
local options = {
	type = "group",
	name = "ezInterrupt Configuration",
	handler = ezInterrupt,
	args = {
		Main = {
			type = "group",
			name = L["Main Options"],
			args = {
				Enable = {
					type = "toggle",
					name = L["Enable Addon"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.enableAddon = val 
						if ezInterrupt.db.profile.enableAddon then 
							ezInterrupt:Enable() 
						else 
							ezInterrupt:Disable() 
						end 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.enableAddon 
						end,
					order = 1
				},
			},		
		},
		Announcements = {
			type = "group",
			name = L["Announcements"],
			args = {
				Announce = {
					type = "toggle",
					name = L["Announce Successful Interrupts"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.enableAnnouncing = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.enableAnnouncing 
						end,
					order = 2
				},
				Output = {
					type = "group",
					name = L["Output Channels"],
					inline = true,
					order = 2,
					args = {
						Desc = {
							type = "description",
							name = L["OUTPUT_CHANNEL_DESC"],
							order = 1
						},
						Header = {
							type = "header",
							name = L["Always available"],
							order = 2
						},
						System = {
							type = "toggle",
							name = L["Self"],
							desc = L["Shows an interrupt message in your current chat window that only you can see."],
							set = function(info, val) 
								ezInterrupt.db.profile.useSelf = val 
								ezInterrupt:UpdateOutputChannel()
								end,
							get = function(info) 
								return ezInterrupt.db.profile.useSelf 
								end,
							order = 3
						},
						Groupsheader = {
							type = "header",
							name = L["Available in groups and raids"],
							order = 4
						},
						Say = {
							type = "toggle",
							name = L["Say"],
							desc = L["Sends the interrupt message using /say."],
							set = function(info, val) 
								ezInterrupt.db.profile.useSay = val 
								ezInterrupt:UpdateOutputChannel()
								end,
							get = function(info) 
								return ezInterrupt.db.profile.useSay 
								end,
							order = 5
						},
						Party = {
							type = "toggle",
							name = L["Party"],
							desc = L["Sends the interrupt message using /party."],
							set = function(info, val) 
								ezInterrupt.db.profile.useParty = val 
								ezInterrupt:UpdateOutputChannel() 
								end,
							get = function(info) 
								return ezInterrupt.db.profile.useParty 
								end,
							order = 6
						},
						Raidheader = {
							type = "header",
							name = L["Available in raids only"],
							order = 7
						},
						Raid = {
							type = "toggle",
							name = L["Raid"],
							desc = L["Sends the interrupt message using /raid."],
							width = "full",
							set = function(info, val) 
								ezInterrupt.db.profile.useRaid = val 
								ezInterrupt:UpdateOutputChannel() 
								end,
							get = function(info) 
								return ezInterrupt.db.profile.useRaid 
								end,
							order = 8
						},
						Whisper = {
							type = "toggle",
							name = L["Whisper"],
							desc = L["Sends the interrupt message to another player using /whisper."],
							set = function(info, val) 
								ezInterrupt.db.profile.useWhisper = val
								ezInterrupt:UpdateOutputChannel()
								end,
							get = function(info) 
								return ezInterrupt.db.profile.useWhisper 
								end,
							order = 9
						},
						Channel = {
							type = "toggle",
							name = L["Custom Channel"],
							desc = L["Sends the interrupt message to a custom channel of your choice."],
							set = function(info, val) 
								ezInterrupt.db.profile.useCustomChannel = val 
								ezInterrupt:UpdateOutputChannel()
								end,
							get = function(info) 
								return ezInterrupt.db.profile.useCustomChannel 
								end,
							order = 10
						},
						Recipient = {
							type = "input", 
							name = L["Whisper Recipient"],
							desc = L["Insert the name of the player that should be whispered."],
							disabled = function() return not ezInterrupt.db.profile.useWhisper end,
							set = function(info, val) 
								if val == "" then
									ezInterrupt.db.profile.whisperRecipient = nil
								else	
									ezInterrupt.db.profile.whisperRecipient = val
								end
								ezInterrupt:UpdateOutputChannel()
								end,
							get = function(info) 
								return ezInterrupt.db.profile.whisperRecipient 
								end,
							order = 11
						},
						Number = {
							type = "input",
							name = L["Channel Number"],
							disabled = function() return not ezInterrupt.db.profile.useCustomChannel end,
							desc = L["Insert the number of the custom channel to be used. Example: 5"],
							set = function(info, val) 
								if val == "" then 
									ezInterrupt.db.profile.customChannel = nil 
								else 
									ezInterrupt.db.profile.customChannel = val
								end 
								ezInterrupt:UpdateOutputChannel()
								end,
							get = function(info) 
								return ezInterrupt.db.profile.customChannel 
								end,
							order = 12
						},
					},
				},
				Msg = {
					type = "group",
					name = L["Customize Interrupt Message"],
					inline = true,
					order = 3,
					args = {
						Desc = {
							type = "description",
							name = L["CUSTOMIZE_INTERRUPT_MSG_DESC"],
							order = 1
						},
						Msg = {
							type = "input",
							name = L["Message"],
							width = "full",
							set = function(info, val) 
								if val == "" then 
									ezInterrupt.db.profile.customMsg = defaults.profile.customMsg
								else 
									ezInterrupt.db.profile.customMsg = val 
								end 
								end,
							get = function(info) 
								return ezInterrupt.db.profile.customMsg 
								end,
							order = 2
						},
					},
				},
			},
		},
		Instances = {
			type = "group",
			name = L["Instance Settings"],
			args = {
				Desc = {
					type = "description",
					name = L["These settings define where the addon will be active."],
					order = 1,
				},
				World = {
					type = "toggle",
					name = L["Active when not in an instance"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.activeInWorld = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.activeInWorld 
						end,
					order = 2
				},
				Raid = {
					type = "toggle",
					name = L["Active in Raid Instances"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.activeInRaid = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.activeInRaid 
						end,
					order = 3
				},
				Party = {
					type = "toggle",
					name = L["Active in Party Instances"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.activeInParty = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.activeInParty 
						end,
					order = 4,
				},
				Bg = {
					type = "toggle",
					name = L["Active in Battlegrounds"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.activeInBg = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.activeInBg 
						end,
					order = 5
				},		
				Arena = {
					type = "toggle",
					name = L["Active in Arenas"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.activeInArena = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.activeInArena 
						end,
					order = 6
				},
			},
		},
		Alerts = {
			type = "group",
			name = L["Cast Alerts"],
			args = {
				Enable = {
					type = "toggle",
					name = L["Enable Cast Alerts"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.enableCastAlerts = val 
						ezInterrupt:UpdateRegisteredEvents() 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.enableCastAlerts 
						end,
					order = 1
				},
				Sound = {
					type = "toggle",
					name = L["Cast Alert: Play Sound"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.enableSound = val 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.enableSound 
						end,
					order = 2,
				},
				Icon = {
					type = "toggle",
					name = L["Cast Alert: Show Icon"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.enableIcon = val 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.enableIcon 
						end,
					order = 3
				},
				Flash = {
					type = "toggle",
					name = L["Cast Alert: Screen Flash"],
					width = "full",
					set = function(info, val) 
						ezInterrupt.db.profile.enableFlash = val 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.enableFlash 
						end,
					order = 4
				},
				Trigger = {
					type = "group",
					name = L["Trigger Unit"],
					inline = true,
					order = 6,
					args = {
						Desc = {
							type = "description",
							name = L["This setting defines who can trigger cast alerts."],
							order = 1,
						},
						Unit = {
							type = "select",
							name = L["Select Unit"],
							style = "dropdown",
							values = {["target"]=L["Target"],["focus"]=L["Focus"]},
							set = function(info, val) 
								ezInterrupt.db.profile.triggerUnit = val
								TRIGGER_UNIT_BITMASK = _G["COMBATLOG_OBJECT_"..string.upper(val)]
								end,
							get = function(info) 
								return ezInterrupt.db.profile.triggerUnit 
								end,
							order = 2
						},	
					},
				},
				Filtering = {
					type = "group",
					name = L["Spell Filtering"],
					inline = true,
					order = 5,
					args = {
						Desc = {
							type = "description",
							name = L["SPELL_FILTERING_DESC"],
							order = 1,
						},
						Mode = {
							type = "select",
							name = L["Filtering Mode"],
							style = "dropdown",
							width = "full",
							values = {[1]=L["Disabled"],[2]=L["Blacklist"],[3]=L["Whitelist"]},
							set = function(info, val) 
								ezInterrupt.db.profile.filterMode = val
								end,
							get = function(info) 
								return ezInterrupt.db.profile.filterMode 
								end,
							order = 2
						},
						BlacklistAdd = {
							type = "input",
							name = L["Blacklist: Add Spell"],
							desc = L["Insert the name of a spell to add it. Note: spell IDs do not work, only spell names do."],
							set = function(info, val) 
								ezInterrupt:AddonMsg(L["added %s to the Blacklist"]:format(val))
								table.insert(ezInterrupt.db.profile.blackList, val)
							end,
							get = false,
							order = 3
						},
						BlacklistRemove = {
							type = "select", 
							style = "dropdown",
							name = L["Blacklist: Remove Spell"],
							disabled = function() return #ezInterrupt.db.profile.blackList == 0 end,
							values = function() return ezInterrupt.db.profile.blackList end,
							set = function(info, val) 
								ezInterrupt:AddonMsg(L["removed %s from the Blacklist"]:format(ezInterrupt.db.profile.blackList[val]))
								table.remove(ezInterrupt.db.profile.blackList, val)
							end,
							get = false,
							order = 4
						},
						WhitelistAdd = {
							type = "input",
							name = L["Whitelist: Add Spell"],
							desc = L["Insert the name of a spell to add it. Note: spell IDs do not work, only spell names do."],
							set = function(info, val) 
								ezInterrupt:AddonMsg(L["added %s to the Whitelist"]:format(val))
								table.insert(ezInterrupt.db.profile.whiteList, val)
							end,
							get = false,
							order = 5
						},
						WhitelistRemove = {
							type = "select", 
							style = "dropdown",
							name = L["Whitelist: Remove Spell"],
							disabled = function() return #ezInterrupt.db.profile.whiteList == 0 end,
							values = function() return ezInterrupt.db.profile.whiteList end,
							set = function(info, val) 
								ezInterrupt:AddonMsg(L["removed %s from the Whitelist"]:format(ezInterrupt.db.profile.whiteList[val]))
								table.remove(ezInterrupt.db.profile.whiteList, val)
							end,
							get = false,
							order = 6
						},
					}, 
				},	
			},
		},
		Graphics = {
			type = "group",
			name = L["Graphics Settings"],
			args = {
				Desc = {
					type = "description",
					name = L["This section allows you to customize the icon and screen flash shown during cast alerts."],
					order = 1,
				},				
				Scale = {
					type = "range",
					name = L["Icon Size"],
					min = 16,
					max = 256,
					set = function(info, val) 
						ezInterrupt.db.profile.iconSize = val 
						WarningFrame:SetWidth(val) 
						WarningFrame:SetHeight(val) 
						WarningFrame.Icon:SetPoint("TOPLEFT", val/16, -val/16) 
						WarningFrame.Icon:SetPoint("BOTTOMRIGHT", -val/16, val/16)	 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.iconSize 
						end,
					order = 2
				},		
				Alpha = {
					type = "range",
					name = L["Icon Alpha"],
					min = 0.1,
					max = 1,
					isPercent = true,
					set = function(info, val) 
						ezInterrupt.db.profile.iconAlpha = val 
						WarningFrame:SetAlpha(val) 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.iconAlpha 
						end,
					order = 3
				},	
				Blending = {
					type = "select",
					name = L["Icon Blend Mode"],
					desc = L["Sets the icon's texture blend mode. Standard does not alter colors. Additive brightens up the texture by replacing dark areas with transparent ones."],
					style = "dropdown",
					values = {["BLEND"]=L["Standard"],["ADD"]=L["Additive"]},
					set = function(info, val) 
						ezInterrupt.db.profile.iconBlending = val 
						WarningFrame.Border:SetBlendMode(val) 
						WarningFrame.Icon:SetBlendMode(val) 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.iconBlending 
						end,
					order = 4
				},
				Unlock = {
					type = "execute",
					name = L["Unlock Icon"],
					desc = L["Unlocking allows you to drag the cast alert icon by holding down the left mouse button."],
					func = function() 
						HideUIPanel(InterfaceOptionsFrame)
						HideUIPanel(GameMenuFrame)
						ezInterrupt:Unlock() 
						end,
					order = 5
				},
				FlashAlpha = {
					type = "range",
					name = L["Screen Flash Alpha"],
					min = 0.2,
					max = 1,
					isPercent = true,
					set = function(info, val) 
						ezInterrupt.db.profile.flashAlpha = val 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.flashAlpha 
						end,
					order = 6
				},
				FlashDuration = {
					type = "range",
					name = L["Screen Flash Duration"],
					min = 0.1,
					max = 1.5,
					set = function(info, val) 
						ezInterrupt.db.profile.flashDuration = val 
						end,
					get = function(info) 
						return ezInterrupt.db.profile.flashDuration
						end,
					order = 7
				},
				TestFlash = {
					type = "execute",
					name = L["Show Example Flash"],
					func = function() ezInterrupt:ScreenFlash(unpack(ezInterrupt.Interrupt[1].rgb)) end,
					order = 8
				},
			}
		},
		Interrupts = {
			type = "group",
			name = L["Interrupts"],
			args = {
				Desc = {
					type = "description",
					name = L["CUSTOMIZE_INTERRUPTS_DESC"],
					order = 1
				},
			}
		}
	}
}

function ezInterrupt:AddonMsg(msg)
	SELECTED_CHAT_FRAME:AddMessage("|cFFff9000ez|r|cFFccff1dInterrupt:|r "..msg)
end

function ezInterrupt:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ezInterruptDB", defaults, "Default")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ezInterrupt", options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ezInterrupt", "ezInterrupt", nil, "Main")
	self.optionsFrame.Alerts = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ezInterrupt", L["Cast Alerts"], "ezInterrupt", "Alerts")
	self.optionsFrame.Announcements = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ezInterrupt", L["Announcements"], "ezInterrupt", "Announcements")
	self.optionsFrame.Instances = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ezInterrupt", L["Instance Settings"], "ezInterrupt", "Instances")
	self.optionsFrame.Graphics = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ezInterrupt", L["Graphics"], "ezInterrupt", "Graphics")
	self.optionsFrame.Interrupts = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ezInterrupt", L["Interrupts"], "ezInterrupt", "Interrupts")
	options.args.Main.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db) -- add wowace profile menu to the options table
	options.args.Main.args.profiles.inline = true
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self:SetEnabledState(self.db.profile.enableAddon)
	self:UpdateIcon()
	TRIGGER_UNIT_BITMASK = _G["COMBATLOG_OBJECT_"..string.upper(self.db.profile.triggerUnit)]
	class = select(2, UnitClass("player"))
	-- self:UpdateInterrupts() --> using PLAYER_ALIVE instead to get correct talent info on first init. probably not optimal but it works
	self:RegisterEvent("PLAYER_ALIVE")
end

function ezInterrupt:PLAYER_ALIVE()
	self:UnregisterEvent("PLAYER_ALIVE")
	self:UpdateInterrupts()
end

function ezInterrupt:OnEnable()
	self:UpdateInterrupts()
	self:UpdateOutputChannel()
	self:UpdateRegisteredEvents()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateOutputChannel")
end

function ezInterrupt:OnDisable()
	self:StopAlert()
end

local function CooldownTracker_OnUpdate(self,elapsed)
	self.total = self.total + elapsed
	local startTime, cd, enable = GetSpellCooldown(self.spell)
	if cd == 0 then
		ezInterrupt.Interrupt[self.index].ready = true
		ezInterrupt:CastAlertHandler(self.index)
		self:SetScript("OnUpdate",nil)
	elseif self.check == true and self.total >= self.limit then
		self.check = false
		ezInterrupt:CastAlertHandler(self.index)
	end
end

CooldownTracker:SetScript("OnEvent", function(self,event)
	for i=1,#ezInterrupt.Interrupt do
		if ezInterrupt.Interrupt[i].enabled and ezInterrupt.Interrupt[i].ready == true then
			local startTime, cd, enable = GetSpellCooldown(ezInterrupt.Interrupt[i].id)
			if cd > 0 then
				ezInterrupt.Interrupt[i].ready = false
				local f = CreateFrame("Frame")
				f.total = 0
				f.limit = cd-latencyOffset
				f.spell = ezInterrupt.Interrupt[i].id
				f.index = i
				f.check = true
				f:SetScript("OnUpdate", CooldownTracker_OnUpdate)
			end
		end
	end
end)

function ezInterrupt:LoadInterruptSettings(index, interrupt)
	if not self.Interrupt[index] then self.Interrupt[index] = {} end
	self.Interrupt[index].userenabled = self.db.profile.interruptSettings[interrupt].userenabled
	self.Interrupt[index].id = self.db.profile.interruptSettings[interrupt].id
	self.Interrupt[index].sound = self.db.profile.interruptSettings[interrupt].sound
	self.Interrupt[index].rgb = self.db.profile.interruptSettings[interrupt].rgb
end

function ezInterrupt:UpdateInterrupts()
	if not self.Interrupt then self.Interrupt = {} end
	if class == "WARRIOR" then
		self:LoadInterruptSettings(1, 6552)			-- Pummel
		self:LoadInterruptSettings(2, 102060)			-- Disrupting Shout!
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(3, 69179)	-- Arcane Torrent (Rage)
		end
	elseif class == "DRUID" then
		self:LoadInterruptSettings(1, 80964)		-- Skull Bash (Bear)
		self:LoadInterruptSettings(2, 80965) 		-- Skull Bash (Cat)
	elseif class == "ROGUE" then
		self:LoadInterruptSettings(1, 1766)			-- Kick
		self:LoadInterruptSettings(2, 26679)		-- Deadly Throw
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(3, 25046)	-- Arcane Torrent (Energy)
		end
		self:UpdateTalentedInterrupts()
		self:RegisterEvent("LEARNED_SPELL_IN_TAB", "UpdateTalentedInterrupts")
	elseif class == "PALADIN" then
		self:LoadInterruptSettings(1, 96231)		-- Rebuke
		self:LoadInterruptSettings(2, 31935)		-- Avenger's Shield
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(3, 28730)	-- Arcane Torrent (Mana)
		end
		self:UpdateTalentedInterrupts()
		self:RegisterEvent("LEARNED_SPELL_IN_TAB", "UpdateTalentedInterrupts")
	elseif class == "DEATHKNIGHT" then
		self:LoadInterruptSettings(1, 47528)		-- Mind Freeze
		self:LoadInterruptSettings(2, 47476)		-- Strangulate
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(3, 50613)	-- Arcane Torrent (RP)
		end
	elseif class == "SHAMAN" then
		self:LoadInterruptSettings(1, 57994)		-- Wind Shear
	elseif class == "MAGE" then
		self:LoadInterruptSettings(1, 2139)			-- Counterspell
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(2, 28730)	-- Arcane Torrent (Mana)
		end
	elseif class == "WARLOCK" then
		self:LoadInterruptSettings(1, 19647)		-- 19647
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(2, 28730)	-- Arcane Torrent (Mana)
		end
		self:UpdatePetInterrupts(_,"player")
		self:RegisterEvent("UNIT_PET", "UpdatePetInterrupts")
	elseif class == "HUNTER" then
		self:LoadInterruptSettings(1, 34490)		-- Silencing Shot
		self:LoadInterruptSettings(2, 26090)		-- Pummel (Gorilla)
		self:LoadInterruptSettings(3, 50479)		-- Nether Shock
		self:LoadInterruptSettings(4, 50318)		-- Serenity Dust
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(5, 80483)	-- Arcane Torrent (Focus)
		end
		self:UpdateTalentedInterrupts()
		self:RegisterEvent("LEARNED_SPELL_IN_TAB", "UpdateTalentedInterrupts")
		self:UpdatePetInterrupts(_,"player")
		self:RegisterEvent("UNIT_PET", "UpdatePetInterrupts")
	elseif class == "PRIEST" then
		self:LoadInterruptSettings(1, 15487)		-- Silence
		if select(2, UnitRace("player")) == "BloodElf" then
			self:LoadInterruptSettings(2, 28730)	-- Arcane Torrent (Mana)
		end
		self:UpdateTalentedInterrupts()
		self:RegisterEvent("LEARNED_SPELL_IN_TAB", "UpdateTalentedInterrupts")
	end
	
	-- fill in "enable" and "ready" keys where they are missing
	for i=1,#self.Interrupt do
		if self.Interrupt[i].enabled == nil then
			self.Interrupt[i].enabled = true 
		end

		if self.Interrupt[i].ready == nil then
			local startTime, cd, enable = GetSpellCooldown(self.Interrupt[i].id)
			if cd == 0 then 
				self.Interrupt[i].ready = true
				
			else
				self.Interrupt[i].ready = false
				local f = CreateFrame("Frame")
				f.total = 0
				f.limit = startTime+cd-GetTime()-latencyOffset
				f.spell = ezInterrupt.Interrupt[i].id
				f.index = i
				f.check = false --> disable early cast check since it doesn't seem to work properly when starting a tracker during init
				f:SetScript("OnUpdate", CooldownTracker_OnUpdate)
			end
		end
		--> create config options for each interrupt
		if not options.args.Interrupts.args["Interrupt"..i] then
			local spellname,_,texture,_,_,_,_,_,_ = GetSpellInfo(self.Interrupt[i].id)
			options.args.Interrupts.args["Interrupt"..i] = {
				type = "group",
				name = spellname,
				inline = true,
				order = i,
				args = {
					Toggle = {
						type = "toggle",
						name = L["Allow Cast Alerts for this interrupt"],
						width = "full",
						set = function(info, val) 
								self.Interrupt[i].userenabled = val 
								ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].userenabled = val
							end,
						get = function(info)
								return ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].userenabled
							end,
						order = 1
					},
					Color = {
						type = "color",
						name = L["Associated Color"],
						set = function(info, r, g, b)
								self.Interrupt[i].rgb[1] = r
								self.Interrupt[i].rgb[2] = g
								self.Interrupt[i].rgb[3] = b
								ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].rgb[1] = r
								ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].rgb[2] = g
								ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].rgb[3] = b
							end,
						get = function(info)
								return unpack(ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].rgb)
							end,
						order = 2
					},
					Sound = {
						type = "select",
						dialogControl = "LSM30_Sound",
						name = L["Associated Sound"],
						style = "dropdown",
						values = AceGUIWidgetLSMlists.sound,
						set = function(info, val)
								self.Interrupt[i].sound = val
								ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].sound = val
							end,
						get = function(info)
								return ezInterrupt.db.profile.interruptSettings[self.Interrupt[i].id].sound
							end,
						order = 3
					},
				}
			}
		end
	end
end

function ezInterrupt:UpdatePetInterrupts(event,unit)
	if unit == "player" then
		if class == "WARLOCK" then
			self.Interrupt[1].enabled = UnitCreatureFamily("pet") == L["Felhunter"]
		elseif class == "HUNTER" then
			self.Interrupt[2].enabled = UnitCreatureFamily("pet") == L["Gorilla"]
			self.Interrupt[3].enabled = UnitCreatureFamily("pet") == L["Nether Ray"]
			self.Interrupt[4].enabled = UnitCreatureFamily("pet") == L["Moth"]
		end
	end
end

function ezInterrupt:UpdateTalentedInterrupts(event)
--	if class == "PRIEST" then
--		self.Interrupt[1].enabled = select(5, GetTalentInfo(3, 11, false)) > 0
--	elseif class == "HUNTER" then
--		self.Interrupt[1].enabled = select(5, GetTalentInfo(2, 7, false)) > 0
--	elseif class == "ROGUE" then
--		 self.Interrupt[2].enabled = select(5, GetTalentInfo(2, 14, false)) > 0		
--	elseif class == "PALADIN" then
--		self.Interrupt[2].enabled = GetPrimaryTalentTree() == 2
--	end
end

function ezInterrupt:UpdateIcon()
	if not WarningFrame then
		WarningFrame = CreateFrame("FRAME", "ezInterruptMainFrame", UIParent)
		WarningFrame:SetFrameStrata("HIGH")
		WarningFrame:SetClampedToScreen(true)
		WarningFrame.Icon = WarningFrame:CreateTexture("ezInterruptIcon", "background")
		WarningFrame.Icon:SetDrawLayer("background", 0)
		WarningFrame.Icon:SetTexCoord(0.0625,0.9375,0.0625,0.9375)
		WarningFrame.Icon:SetTexture("Interface\\Icons\\Spell_Fire_SealOfFire")	
		WarningFrame.Border = WarningFrame:CreateTexture("ezInterruptIconBorder", "border")
		WarningFrame.Border:SetAllPoints()
		WarningFrame.Border:SetTexture("Interface\\Addons\\ezInterrupt\\media\\edge.tga")
		WarningFrame.Border:SetVertexColor(1, 0, 0)
		WarningFrame:SetScript("OnDragStart", function(self, button) 
				self:StartMoving() 
			end)
		WarningFrame:SetScript("OnDragStop", function(self, button) 
				self:StopMovingOrSizing() 
			end)
		WarningFrame:SetScript("OnMouseUp", function(self, button)
				if button == "RightButton" then 
					ezInterrupt:Lock()
				end 
			end)
	end
	WarningFrame:EnableMouse(false)
	WarningFrame:SetMovable(false) 
	WarningFrame:Hide()
	WarningFrame:ClearAllPoints() --
	WarningFrame:SetPoint(unpack(self.db.profile.iconPos))
	WarningFrame:SetWidth(self.db.profile.iconSize)
	WarningFrame:SetHeight(self.db.profile.iconSize)
	WarningFrame:SetAlpha(self.db.profile.iconAlpha)
	WarningFrame.Icon:SetPoint("TOPLEFT", self.db.profile.iconSize/16, -self.db.profile.iconSize/16)
	WarningFrame.Icon:SetPoint("BOTTOMRIGHT", -self.db.profile.iconSize/16, self.db.profile.iconSize/16)
	WarningFrame.Icon:SetBlendMode(self.db.profile.iconBlending)
	WarningFrame.Border:SetBlendMode(self.db.profile.iconBlending)
end

function ezInterrupt:UpdateRegisteredEvents()
	local instanceType = select(2, IsInInstance())
	if (instanceType == "raid" and self.db.profile.activeInRaid) or (instanceType == "party" and self.db.profile.activeInParty) or (instanceType == "pvp" and self.db.profile.activeInBg) or (instanceType == "arena" and self.db.profile.activeInArena) or (instanceType == "none" and self.db.profile.activeInWorld) then
		if self.db.profile.enableAnnouncing then
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		else
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
		if self.db.profile.enableCastAlerts then
			CooldownTracker:RegisterEvent("SPELL_UPDATE_COOLDOWN")
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnCastStop")
			self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnCastStop")
			self:RegisterEvent("UNIT_SPELLCAST_START", "OnCastStart")
			self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnCastStart")
			self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
			self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnTargetChanged")
		else
			CooldownTracker:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			self:UnregisterEvent("UNIT_SPELLCAST_START")
			self:UnregisterEvent("UNIT_SPELLCAST_STOP")
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
			self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
			self:UnregisterEvent("PLAYER_TARGET_CHANGED")
			self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
		end
	else
		CooldownTracker:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
		self:UnregisterEvent("UNIT_SPELLCAST_START")
		self:UnregisterEvent("UNIT_SPELLCAST_STOP")
		self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
	end
end

function ezInterrupt:UpdateOutputChannel()
	local inParty = GetNumSubgroupMembers() > 0
	local inRaid = GetNumGroupMembers() > 0
	if self.db.profile.useWhisper and inRaid and self.db.profile.whisperRecipient then
		outputChannel = "WHISPER"
	elseif self.db.profile.useCustomChannel and inRaid and self.db.profile.customChannel then
		outputChannel = "CHANNEL"
	elseif self.db.profile.useRaid and inRaid then
		outputChannel = "RAID"
	elseif self.db.profile.useParty and (inParty or inRaid) then
		outputChannel = "PARTY"
	elseif self.db.profile.useSay and (inParty or inRaid) then
		outputChannel = "SAY"
	elseif self.db.profile.useSelf then
		outputChannel = "SELF"
	else
		outputChannel = false
	end
end

--> a bit messy, clean it up
function ezInterrupt:OnProfileChanged()
	local OnEnableCalled
	if self.db.profile.enableAddon then 
		OnEnableCalled = self:Enable()
	else
		self:Disable()
	end
	if not OnEnableCalled then
		self:UpdateInterrupts()
		self:UpdateOutputChannel()
		self:UpdateRegisteredEvents()
	end
	self:UpdateIcon()
	TRIGGER_UNIT_BITMASK = _G["COMBATLOG_OBJECT_"..string.upper(self.db.profile.triggerUnit)]
	LibStub("AceConfigRegistry-3.0"):NotifyChange("ezInterrupt")
end

function ezInterrupt:PLAYER_ENTERING_WORLD()
	self:UpdateOutputChannel()
	self:UpdateRegisteredEvents()
end

function ezInterrupt:IsInterruptReady(index)
	if index then
		if self.Interrupt[index].userenabled then
			return true, self.Interrupt[index].sound, self.Interrupt[index].rgb
		else
			return false
		end
	else
		for i=1,#self.Interrupt do
			if self.Interrupt[i].enabled and self.Interrupt[i].userenabled then
				local ready, lacksResource = IsUsableSpell(self.Interrupt[i].id) -- required for druid forms and other things
				if (ready or lacksResource) and GetSpellCooldown(self.Interrupt[i].id) == 0 then
					return true, self.Interrupt[i].sound, self.Interrupt[i].rgb
				end
			end
		end
		return false
	end
end

function ezInterrupt:CheckSpellFilter(spellName)
	if (self.db.profile.filterMode == 2 and tContains(self.db.profile.blackList, spellName)) or (self.db.profile.filterMode == 3 and not tContains(self.db.profile.whiteList, spellName)) then
		return false
	else
		return true
	end
end

function ezInterrupt:OnCastStop(_,unitID)
	if unitID == ezInterrupt.db.profile.triggerUnit and UnitCanAttack("player", unitID) then
		self:StopAlert()
	end
end

function ezInterrupt:OnCastStart(_,unitID)
	if unitID == self.db.profile.triggerUnit and UnitCanAttack("player", unitID) then
		self:CastAlertHandler()
	end
end

function ezInterrupt:OnTargetChanged()
	lastSoundAlert = 0
	if UnitCanAttack("player", self.db.profile.triggerUnit) then 
		self:CastAlertHandler()
	else
		self:StopAlert()
	end
end

function ezInterrupt:CastAlertHandler(index) -- index is optional and used to avoid having IsInterruptReady check the ability cooldown
	local spellName,_,_,texture,_,_,_,_,notInterruptible = UnitCastingInfo(self.db.profile.triggerUnit) 
	if not spellName then
		spellName,_,_,texture,_,_,_,notInterruptible = UnitChannelInfo(self.db.profile.triggerUnit) 
	end
	if spellName and notInterruptible == false and self:CheckSpellFilter(spellName) then
		local ready, sound, rgb = self:IsInterruptReady(index)
		if ready then
			if self.db.profile.enableSound and lastSoundAlert+0.25 < GetTime() then 
				lastSoundAlert = GetTime()
				PlaySoundFile(LSM:Fetch("sound", sound), "MASTER")
			end
			if self.db.profile.enableIcon then
				WarningFrame.Icon:SetTexture(texture)
				WarningFrame.Border:SetVertexColor(unpack(rgb))
				WarningFrame:Show()
			end
			if self.db.profile.enableFlash then
				self:ScreenFlash(unpack(rgb))
			end
			return
		end
	end
	self:StopAlert()
end

function ezInterrupt:StopAlert()
	WarningFrame:Hide()
end

function ezInterrupt:COMBAT_LOG_EVENT_UNFILTERED(_,_,event,_,_,_,sourceFlags,_,_,destName,_,_,spellID,_,_,extraID)
	if self.db.profile.enableAnnouncing and bit_and(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 and event == "SPELL_INTERRUPT" then
		msgTags[L["[spell]"]] = GetSpellLink(extraID)
		msgTags[L["[target]"]] = destName
		msgTags[L["[interrupt]"]] = GetSpellLink(spellID)
		local msg = gsub(self.db.profile.customMsg, "%[%a+%]", msgTags)
		if not outputChannel then return end
		if outputChannel == "WHISPER" then
			SendChatMessage(msg, "WHISPER", nil, self.db.profile.whisperRecipient)
		elseif outputChannel == "CHANNEL" then
			SendChatMessage(msg, "CHANNEL", nil, self.db.profile.customChannel)
		elseif outputChannel == "SELF" then
			SELECTED_CHAT_FRAME:AddMessage(msg)
		else
			SendChatMessage(msg, outputChannel)
		end
	end
	-- detection of auras granting immunity to interrupts is not currently working as intended
	if self.db.profile.enableCastAlerts and bit_and(sourceFlags, TRIGGER_UNIT_BITMASK) ~= 0 and bit_and(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 and ImmunityAuras[spellID] == true then
		if event == "SPELL_AURA_REMOVED" then
			
			self:CastAlertHandler()
		elseif event == "SPELL_AURA_APPLIED" then
			
			self:StopAlert()
		end
	end
end

function ezInterrupt:Unlock()
	if not WarningFrame.UnlockMsg then 
		WarningFrame.UnlockMsg = WarningFrame:CreateFontString("ARTWORK")
		WarningFrame.UnlockMsg:SetFontObject("GameFontHighlight")
		WarningFrame.UnlockMsg:SetJustifyH("MIDDLE")
		WarningFrame.UnlockMsg:SetText(L["Right-click to lock"])
		WarningFrame.UnlockMsg:SetPoint("TOP", 0, 12)
	end
	WarningFrame.UnlockMsg:Show()
	WarningFrame:EnableMouse(true) 
	WarningFrame:SetMovable(true) 
	WarningFrame:RegisterForDrag("LeftButton")
	WarningFrame:Show() 
	self:AddonMsg(L["cast alert icon unlocked"])
end

function ezInterrupt:Lock()
	self.db.profile.iconPos = {WarningFrame:GetPoint(1)} 
	WarningFrame.UnlockMsg:Hide()
	WarningFrame:EnableMouse(false) 
	WarningFrame:SetMovable(false) 
	WarningFrame:RegisterForDrag()
	WarningFrame:Hide() 
	self:AddonMsg(L["cast alert icon locked"])
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame.Graphics)
end

function ezInterrupt:ScreenFlash(r, g, b)
	if not Flash then
		Flash = CreateFrame("Frame", "ezInterruptFlash", UIParent)
		Flash:SetFrameStrata("BACKGROUND")
		Flash:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",})
		Flash:SetAllPoints(UIParent)
		Flash.Elapsed = 0
		Flash:Hide()
		Flash:SetScript("OnUpdate", function(self, elapsed)
			self.Elapsed = self.Elapsed + elapsed
			if self.Elapsed >= ezInterrupt.db.profile.flashDuration then
				self:Hide()
				self.Elapsed = 0
				return
			end
		end)
	end
	Flash:SetBackdropColor(r, g, b, self.db.profile.flashAlpha)
	Flash:Show()
end