-- uzelezz smart UwU
-- uzelezz smart UwU
-- Canonical TPIK bone lists. All hg.TPIKBones* tables below are generated
-- from these so external users (homigrad_base, zmanip) see identical content.
local TPIK_FINGERS = {
    "Finger4", "Finger41", "Finger42",
    "Finger3", "Finger31", "Finger32",
    "Finger2", "Finger21", "Finger22",
    "Finger1", "Finger11", "Finger12",
    "Finger0", "Finger01", "Finger02",
}
local TPIK_ALIAS_ORDER = {
    "Hand", "Finger0", "Finger01", "Finger02",
    "Finger1", "Finger11", "Finger12",
    "Finger2", "Finger21", "Finger22",
    "Finger3", "Finger31", "Finger32",
    "Finger4", "Finger41", "Finger42",
}
local function TPIK_Full(side, part)
    return "ValveBiped.Bip01_" .. side .. "_" .. part
end
local function TPIK_BuildSideList(side)
    local t = { TPIK_Full(side, "Hand") }
    for _, f in ipairs(TPIK_FINGERS) do t[#t + 1] = TPIK_Full(side, f) end
    return t
end
local function TPIK_BuildIdentity(list)
    local d = {}
    for _, b in ipairs(list) do d[b] = b end
    return d
end
local function TPIK_BuildDict(side)
    local short = (side == "R") and "R " or "L "
    local bip = (side == "R") and "Bip01 R " or "Bip01 L "
    local d = TPIK_BuildIdentity(TPIK_BuildSideList(side))
    for _, part in ipairs(TPIK_ALIAS_ORDER) do
        d[short .. part] = TPIK_Full(side, part)
        d[bip .. part] = TPIK_Full(side, part)
    end
    return d
end
local function TPIK_BuildMirrorDict()
    local d = {}
    for _, f in ipairs(TPIK_ALIAS_ORDER) do
        d[TPIK_Full("R", f)] = TPIK_Full("L", f)
    end
    for _, part in ipairs(TPIK_ALIAS_ORDER) do
        d["R " .. part] = TPIK_Full("L", part)
        d["Bip01 R " .. part] = TPIK_Full("L", part)
    end
    return d
end
local TPIKBonesRH = TPIK_BuildSideList("R")
local TPIKBonesLH = TPIK_BuildSideList("L")
local TPIKBones = {
    TPIK_Full("L", "Wrist"), TPIK_Full("L", "Ulna"),
    unpack(TPIKBonesLH),
    TPIK_Full("R", "Wrist"), TPIK_Full("R", "Ulna"),
    unpack(TPIKBonesRH),
}
local TPIKBonesTranslate = TPIK_BuildIdentity(TPIKBonesLH)
for k, v in pairs(TPIK_BuildIdentity(TPIKBonesRH)) do TPIKBonesTranslate[k] = v end
local TPIKBonesRHDict = TPIK_BuildDict("R")
local TPIKBonesLHDict = TPIK_BuildDict("L")
local TPIKBonesRHDictTranslate = TPIK_BuildMirrorDict()
hg.TPIKBonesRHDict = TPIKBonesRHDict
hg.TPIKBonesLHDict = TPIKBonesLHDict
hg.TPIKBonesRHDictTranslate = TPIKBonesRHDictTranslate
hg.TPIKBones = TPIKBones
hg.TPIKBonesTranslate = TPIKBonesTranslate
hg.TPIKBonesOther = {
    "ValveBiped.Bip01_R_Clavicle",
    "ValveBiped.Bip01_R_UpperArm",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_L_Clavicle",
    "ValveBiped.Bip01_L_UpperArm",
    "ValveBiped.Bip01_L_Forearm"
}
hg.TPIKBonesRH = TPIKBonesRH
hg.TPIKBonesLH = TPIKBonesLH

local math, Vector, Angle, util, IsValid, CurTime, game, FrameTime, LerpAngle = math, Vector, Angle, util, IsValid, CurTime, game, FrameTime, LerpAngle
local math_Clamp = math.Clamp

local developer = GetConVar("developer")


local vecUpX, vecUpZ, vecUpY, vecZero, angZero = Vector(1, 0, 0), Vector(0, 0, 1), Vector(0, 1, 0), Vector(0, 0, 0), Angle(0, 0, 0)

local cached_huy = {}

--local hg_coolgloves = ConVarExists("hg_coolgloves") and GetConVar("hg_coolgloves") or CreateClientConVar("hg_coolgloves", 0, true, false, "Enable cool gloves (only firstperson) (laggy)", 0, 1)
--local hg_change_gloves = ConVarExists("hg_change_gloves") and GetConVar("hg_change_gloves") or CreateClientConVar("hg_change_gloves", 1, true, false, "Change cool gloves model (only with hg_coolgloves enabled)", 0, 5)

local vector_small = Vector(0,0,0)
local vector_small2 = Vector(0.001,0.001,0.001)

--[[local gloves = {
	[0] = Model("models/weapons/c_arms_citizen.mdl"),
	[1] = Model("models/weapons/c_arms_combine.mdl"),
	[2] = Model("models/epangelmatikes/e3_elite_suit.mdl"),
	[3] = Model("models/pms/quantum_break/characters/operators/monarchoperator01playermodel.mdl"),
	[4] = Model("models/kuma96/gta5_splintercell/gta5_splintercell_pm.mdl"),
	[5] = Model("models/blacklist/spy1.mdl"),
}

for k, v in ipairs(gloves) do
	util.PrecacheModel(v)
end

local blackmans = {
	["models/player/corpse1.mdl"] = true,
	["models/player/group01/female_03.mdl"] = true,
	["models/player/group01/male_01.mdl"] = true,
	["models/player/group01/male_03.mdl"] = true,
	["models/player/group03/male_01.mdl"] = true,
	["models/player/group03/male_03.mdl"] = true,
	["models/player/group03m/male_01.mdl"] = true,
	["models/player/group03m/male_03.mdl"] = true,
	["models/monolithservers/mpd/male_01.mdl"] = true,
	["models/monolithservers/mpd/male_03.mdl"] = true,
	["models/monolithservers/mpd/female_03.mdl"] = true,
}]]

local hg, LocalToWorld = hg, LocalToWorld
local durachok = "models/epangelmatikes/e3_elite_suit.mdl"

--hook.Add("PostDrawPlayerRagdoll", "!!!!!!!zcity_PostDrawPlayerRagdollmain", function(ent, ply)
local ang_head1, ang_head2 = Angle(-90, 0, 220), Angle(-90, 0, -30)
function hg.MainTPIKFunction(ent, ply, wpn)
    if not IsValid(ply) then return end
    if not ply:IsPlayer() then return end
    if not ply.InVehicle then return end
    
    //local systime = SysTime()
    local should = hg.ShouldTPIK(ply)
    //print("shouldtpik func: ", SysTime() - systime)

    if should then
        if ent != ply then
            //ent:SetupBones()
        end
        
        //local systime = SysTime()
        if wpn.SetHandPos then
            wpn:SetHandPos()
        end

        //print("sethandpos: ", SysTime() - systime)
        
        if ply:InVehicle() then
            --print(ply:IsDrivingSimfphys())
            local Car = ply.IsDrivingSimfphys and ply.GetSimfphys and ply:IsDrivingSimfphys() and IsValid(ply:GetSimfphys()) and ply:GetSimfphys() or (ply.GlideGetVehicle and IsValid(ply:GlideGetVehicle()) and ply:GlideGetSeatIndex() == 1 and ply:GlideGetVehicle() ) or ply:GetVehicle()
            if(IsValid(Car))then
                Car:SetupBones()
                local bone,adjust = hg.GetCarSteering(Car)
                --print(adjust)
                
                if bone and Car:GetBoneMatrix(bone) and wpn and not wpn.reload then
                    local pos, ang = Car:GetBoneMatrix(bone):GetTranslation(), Car:GetBoneMatrix(bone):GetAngles()

                    pos, ang = LocalToWorld(adjust[1], adjust[2], pos, ang)

                    wpn.lhandik = true

                    hg.DragLeftHand_Ex(ent,wpn,pos,ang)
                    if IsValid(wpn) and adjust[3] then
                        pos, ang = Car:GetBoneMatrix(bone):GetTranslation(), Car:GetBoneMatrix(bone):GetAngles()
                        pos, ang = LocalToWorld(adjust[3], adjust[4], pos, ang)
                        ply.lerp_rh = 1
                        wpn.rhandik = true
                        hg.DragRightHand_Ex(ent,wpn,pos,ang)
                    end
                end
            end
            
            --hg.DragHandsToPos(ent,self,ply:GetBoneMatrix(ply:LookupBone("ValveBiped.Bip01_L_Hand")):GetTranslation(),false,0,vector_up,angle_zero,ply:GetBoneMatrix(ply:LookupBone("ValveBiped.Bip01_L_Hand")):GetAngles())
        end

        //local systime = SysTime()
        hg.FlashlightPos(ply)
        //print("FlashlightPos: ", SysTime() - systime)

        //local systime = SysTime()
        if IsValid(wpn) and (wpn:GetClass() ~= "weapon_hands_sh") and IsValid(ply:GetNetVar("carryent2")) then
            hg.DragHands(ply,wpn)
        end
		
		if IsValid(wpn) and wpn:GetClass() == "weapon_hands_sh" and ply:GetNetVar("headcrab") then
			local bone_matrix = ent:GetBoneMatrix(ply:LookupBone("ValveBiped.Bip01_Head1"))
			local pos, ang = bone_matrix:GetTranslation(), bone_matrix:GetAngles()
			hg.DragHandsToPos(ply, ply:GetActiveWeapon(), pos + ang:Right() * 7 - ang:Forward() * 5, true, 5.5, ang:Right(), ang_head1, ang_head2)
		end
        
        //print("DragHands: ", SysTime() - systime)
        hg.DoZManip(ent, ply)
        //local systime = SysTime()
        hg.DoTPIK(ply, ent)
        //print("DoTPIK: ", SysTime() - systime)
    end

    if ent ~= ply and ent.organism and ent.organism.stamina and ent.organism.stamina[1] then
        local stammul = math_Clamp(1 - ent.organism.stamina[1] / 90, 0, 1)

        local holdingrh = ent:GetManipulateBoneAngles(ent:LookupBone("ValveBiped.Bip01_R_Finger11"))[2] < 0
        if holdingrh then
            local rh = ent:LookupBone("ValveBiped.Bip01_R_Hand")
            local rhmat = ent:GetBoneMatrix(rh)

            rhmat:SetTranslation(rhmat:GetTranslation() + VectorRand(-0.2, 0.2) * stammul)

            hg.bone_apply_matrix(ent, rh, rhmat)
        end
        
        local holdinglh = ent:GetManipulateBoneAngles(ent:LookupBone("ValveBiped.Bip01_L_Finger11"))[2] < 0
        if holdinglh then
            local lh = ent:LookupBone("ValveBiped.Bip01_L_Hand")
            local lhmat = ent:GetBoneMatrix(lh)

            lhmat:SetTranslation(lhmat:GetTranslation() + VectorRand(-0.2, 0.2) * stammul)

            hg.bone_apply_matrix(ent, lh, lhmat)
        end
    end
end

--[[hook.Add("IKPoleLeftArm", "asdasdr", function(ply, ent, pos, segments)
    return vector_origin
end)--]]

function hg.CoolGloves(ent, ply)
    if not hg_coolgloves:GetBool() then return end

    local huy = (GetViewEntity() == ply) or (not lply:Alive() and lply:GetNWEntity("spect") == ply and lply:GetNWInt("viewmode",0) == 1)
    
    if ply.GetPlayerClass and ply:GetPlayerClass() and ply:GetPlayerClass().NoGloves or ThatPlyIsFemale(ply) then return end

    if not huy then return end

    if not IsValid(ply.c_hands) then
        ply.c_hands = ClientsideModel(gloves[hg_change_gloves:GetInt()])
        ply.c_hands:SetNoDraw(true)
        ply.c_hands:SetPos(ply:EyePos())
        ply.c_hands:SetParent(ply)
        ply.c_hands.GetPlayerColor = function()
            return ply:GetPlayerColor()
        end
    end
	--ply.c_hands:Remove()
    local mdl = ply.c_hands
    mdl:SetSequence(2)
    mdl:SetCycle(1)--TRI TOPORA
    mdl:SetModel(gloves[hg_change_gloves:GetInt()])
	if (mdl:GetModel() == durachok and mdl:GetBodygroup(1) ~= 1) then
		mdl:SetBodygroup(1, 1)
		mdl:SetBodygroup(2, 1)
	elseif mdl:GetModel() ~= durachok then
		mdl:SetBodygroup(1, 0)
		mdl:SetBodygroup(2, 0)
		mdl:SetSkin(blackmans[lply:GetModel()] and 1 or 0)
	end
    mdl:SetPos(ent:GetPos())
    mdl:SetAngles(ent:GetAngles())
    mdl:SetupBones()

    --local ent2 = wpn.GetWM and IsValid(wpn:GetWM()) and (!wpn.GetFists or wpn:GetFists()) and wpn:GetWM() or ent
    --ply.c_hands:SetParent(ent2)
    
    local mdlmodel = mdl:GetModel()
    cached_huy[mdlmodel] = cached_huy[mdlmodel] or {}
    
    --mdl:RemoveEffects(EF_BONEMERGE)
    --mdl:AddEffects(EF_BONEMERGE)
    
    for bone1 = 0, mdl:GetBoneCount() - 1 do
        if not cached_huy[mdlmodel][bone1] then cached_huy[mdlmodel][bone1] = mdl:GetBoneName(bone1) end
        local bone = cached_huy[mdlmodel][bone1]
        
        local wm_boneindex = mdl:LookupBone(bone)
        if !wm_boneindex then continue end
        local wm_bonematrix = mdl:GetBoneMatrix(wm_boneindex)
        if !wm_bonematrix then continue end
        
        local ply_boneindex = ent:LookupBone(bone) or TPIKBonesTranslate[bone] and ent:LookupBone(TPIKBonesTranslate[bone])
        if !ply_boneindex then continue end
        local ply_bonematrix = ent:GetBoneMatrix(ply_boneindex) or TPIKBonesTranslate[bone] and ent:GetBoneMatrix(ent:LookupBone(TPIKBonesTranslate[bone]))
        if !ply_bonematrix then continue end

        local bonepos = ply_bonematrix:GetTranslation()
        local boneang = ply_bonematrix:GetAngles()
        local scl = ply_bonematrix:GetScale()
        
        if TPIKBonesTranslate[bone] == bone then
            ply_bonematrix:SetScale(vector_small2)
            //ply_bonematrix:SetTranslation(ent:GetBoneMatrix(ent:GetBoneParent(ply_boneindex)):GetTranslation())
            ent:SetBoneMatrix(ent:LookupBone(bone), ply_bonematrix)
            ply_bonematrix:SetScale(scl)
        end
        
        wm_bonematrix:SetTranslation(bonepos)
        wm_bonematrix:SetAngles(boneang)
        wm_bonematrix:SetScale(scl)
        
        --mdl:SetBoneMatrix(wm_boneindex, wm_bonematrix)
        hg.bone_apply_matrix(mdl, wm_boneindex, wm_bonematrix)

        --ent:SetBoneMatrix(ply_boneindex, localmats[bone])

        if !TPIKBonesTranslate[bone] then
            wm_bonematrix:SetScale(vector_small)
            mdl:SetBoneMatrix(wm_boneindex, wm_bonematrix)
		else
			mdl:SetBoneMatrix(wm_boneindex, wm_bonematrix)
		end
    end

    mdl:DrawModel()
end

-- TPIK bone-index cache: LookupBone every frame is expensive.
-- Cached per entity, invalidated when the model changes.
local TPIK_INDEX_NAMES = {
    "head", "pelvis", "l_clavicle", "r_clavicle",
    "l_upperarm", "r_upperarm", "l_forearm", "r_forearm",
    "l_hand", "r_hand", "l_ulna", "r_ulna", "l_wrist", "r_wrist",
}
local TPIK_INDEX_KEYS = {
    head = "ValveBiped.Bip01_Head1",
    pelvis = "ValveBiped.Bip01_Pelvis",
    l_clavicle = "ValveBiped.Bip01_L_Clavicle",
    r_clavicle = "ValveBiped.Bip01_R_Clavicle",
    l_upperarm = "ValveBiped.Bip01_L_UpperArm",
    r_upperarm = "ValveBiped.Bip01_R_UpperArm",
    l_forearm = "ValveBiped.Bip01_L_Forearm",
    r_forearm = "ValveBiped.Bip01_R_Forearm",
    l_hand = "ValveBiped.Bip01_L_Hand",
    r_hand = "ValveBiped.Bip01_R_Hand",
    l_ulna = "ValveBiped.Bip01_L_Ulna",
    r_ulna = "ValveBiped.Bip01_R_Ulna",
    l_wrist = "ValveBiped.Bip01_L_Wrist",
    r_wrist = "ValveBiped.Bip01_R_Wrist",
}
local function TPIK_GetIndices(ent)
    local now = CurTime()
    local c = ent._tpikIdx
    -- Fast path: reuse cache without touching GetModel() (string alloc) every frame.
    -- Revalidate the model at most once per second.
    if c then
        if now - (c.time or 0) < 1 then return c end
        if ent:GetModel() == c.model then c.time = now return c end
    end
    local mdl = ent:GetModel()
    c = { model = mdl, time = now }
    for _, k in ipairs(TPIK_INDEX_NAMES) do
        c[k] = ent:LookupBone(TPIK_INDEX_KEYS[k])
    end
    ent._tpikIdx = c
    return c
end
local function backward(final, segments)
    local inverse = {}

    for i = #final, 1, -1 do
        if i == #final then
            inverse[i] = segments[i]
        else
            local nextpos = inverse[i + 1].Pos
            inverse[i] = {Pos = nextpos + ((final[i].Pos - nextpos):GetNormalized() * final[i].Len), Len = segments[i].Len}
        end
    end
    
    return inverse
end

local function forward(inverse, segments)
    local forward = {}

    for i = 1, #inverse do
        if i == 1 then
            forward[i] = segments[i]
        else
            local prev = forward[i - 1].Pos
            forward[i] = {Pos = prev + ((inverse[i].Pos - prev):GetNormalized() * segments[i - 1].Len), Len = segments[i].Len}
        end
    end

    return forward
end

local function solve(segments, iter, turn)
    local final = {}

    for i = 1, #segments do
        final[i] = segments[i]
    end

    for i = 1, iter do
        final = backward(final, segments)
        final = forward(final, segments)
    end
    
    if segments[1].Pos:DistToSqr(segments[#segments].Pos) < 225 then
        final = backward(final, segments)
    end

    return final
end

function hg.DoTPIK(ply, ent)
    local idx = TPIK_GetIndices(ent)
    local ply_head_index = idx.head
    if !ply_head_index then return end
    local ply_head_matrix = ent:GetBoneMatrix(ply_head_index)
    if not ply_head_matrix then return end

    local ply_spine_index = idx.head
    local ply_spine_matrix = ent:GetBoneMatrix(ply_spine_index)
    if not ply_spine_matrix then return end

    local ply_pelvis_index = idx.pelvis
    if !ply_pelvis_index then return end

    local ply_l_clavicle_index = idx.l_clavicle
    local ply_r_clavicle_index = idx.r_clavicle
    local ply_l_upperarm_index = idx.l_upperarm
    local ply_r_upperarm_index = idx.r_upperarm
    local ply_l_forearm_index = idx.l_forearm
    local ply_r_forearm_index = idx.r_forearm
    local ply_l_hand_index = idx.l_hand
    local ply_r_hand_index = idx.r_hand
    local ply_l_ulna_index = idx.l_ulna
    local ply_r_ulna_index = idx.r_ulna
    local ply_l_wrist_index = idx.l_wrist
    local ply_r_wrist_index = idx.r_wrist

    if !ply_l_upperarm_index then return end
    if !ply_r_upperarm_index then return end
    if !ply_l_forearm_index then return end
    if !ply_r_forearm_index then return end
    if !ply_l_hand_index then return end
    if !ply_r_hand_index then return end

    local self = ply:GetActiveWeapon()

    local lhik2 = ((IsValid(self) and self.lhandik) or ply:InVehicle()) and hg.CanUseLeftHand(ply)
    local rhik2 = ((IsValid(self) and self.rhandik) or ply:InVehicle()) and hg.CanUseRightHand(ply)

    -- Blend first: skip the whole solver when both hands are fully off.
    ply.lerp_lh = math.Approach(ply.lerp_lh or 0, lhik2 and 1 or 0, FrameTime() * 2.0 * game.GetTimeScale())
    ply.lerp_rh = math.Approach(ply.lerp_rh or 0, rhik2 and 1 or 0, FrameTime() * 2.0 * game.GetTimeScale())

    local lerp_lh = math.ease.InOutSine(ply.lerp_lh)
    local lerp_rh = math.ease.InOutSine(ply.lerp_rh)

    if lerp_rh == 0 and lerp_lh == 0 and not ply:InVehicle() then return end

    local _, angarrws = LocalToWorld(vector_origin, ply:InVehicle() and LerpAngle(0.5, ply:EyeAngles(), angle_zero) or ply:EyeAngles(), vector_origin, (IsValid(ply:GetVehicle()) and hg.IsLocal(ply) and ply:GetVehicle():GetAngles() or angle_zero))
    local eyepos, eyeang = ply:EyePos(), angarrws//ply:GetAimVector():Angle()
    local headpos = ply_head_matrix:GetTranslation()

    local ply_r_upperarm_matrix = ent:GetBoneMatrix(ply_r_upperarm_index)
    local ply_r_forearm_matrix = ent:GetBoneMatrix(ply_r_forearm_index)
    local ply_r_hand_matrix = ent:GetBoneMatrix(ply_r_hand_index)
    local ply_r_hand_matrix_old = ply.rhold
    local ply_r_clavicle_matrix = ent:GetBoneMatrix(ply_r_clavicle_index)
    local ply_r_ulna_matrix 
    local ply_r_wrist_matrix
    if ply_r_ulna_index and ply_r_wrist_index then
        ply_r_ulna_matrix = ent:GetBoneMatrix(ply_r_ulna_index)
        ply_r_wrist_matrix = ent:GetBoneMatrix(ply_r_wrist_index)
    end

    local ply_l_upperarm_matrix = ent:GetBoneMatrix(ply_l_upperarm_index)
    local ply_l_forearm_matrix = ent:GetBoneMatrix(ply_l_forearm_index)
    local ply_l_hand_matrix = ent:GetBoneMatrix(ply_l_hand_index)
    local ply_l_hand_matrix_old = ply.lhold
    local ply_l_clavicle_matrix = ent:GetBoneMatrix(ply_l_clavicle_index)
    local ply_l_ulna_matrix 
    local ply_l_wrist_matrix
    if ply_l_ulna_index and ply_l_wrist_index then
        ply_l_ulna_matrix = ent:GetBoneMatrix(ply_l_ulna_index)
        ply_l_wrist_matrix = ent:GetBoneMatrix(ply_l_wrist_index)
    end

    ply.lhold = nil 
    ply.rhold = nil
    if not ply_r_hand_matrix or not ply_l_hand_matrix then return end

    
    local shouldrebuild = false
    if (ply.nextrebuild or 0) < CurTime() then
        ply.nextrebuild = CurTime()

        shouldrebuild = true
    end

    if rhik2 then
        ply.last_rh = ply_r_hand_matrix
    end

    if lhik2 then
        ply.last_lh = ply_l_hand_matrix
    end


    local limblength = ply:BoneLength(ply_l_forearm_index) - 0

    if !limblength or limblength == 0 then limblength = 12 end


    ply.segmentsr = ply.segmentsr or {}
    ply.segmentsr[1] = ply.segmentsr[1] or {Pos = Vector(), Len = 0}
    ply.segmentsr[2] = ply.segmentsr[2] or {Pos = Vector(), Len = 0}

    ply.segmentsl = ply.segmentsl or {}
    ply.segmentsl[1] = ply.segmentsl[1] or {Pos = Vector(), Len = 0}
    ply.segmentsl[2] = ply.segmentsl[2] or {Pos = Vector(), Len = 0}
    

    local spinepos = ply_spine_matrix:GetTranslation()
    local spineang = ply_spine_matrix:GetAngles()

    local up = spineang:Up()
    local spinetan = -math.deg(math.atan2(up.x, up.y)) + 180
    
    if lerp_rh != 0 then
        local segments = ply.segmentsr

        if shouldrebuild or not segments[3] then
            local old = segments[2] and ((segments[2].Pos - segments[1].Pos):GetNormalized() * 2) or vector_origin

            local eyeang = -(-eyeang)
            eyeang.p = math.NormalizeAngle(eyeang.p) * 0.5
            segments[1].Pos = ply_r_upperarm_matrix:GetTranslation()
            segments[1].Len = limblength
            segments[2].Pos = spinepos + eyeang:Right() * 25 - eyeang:Up() * 20 - eyeang:Forward() * 20
            segments[2].Len = limblength

            local tr = util.TraceLine({
                start = segments[1].Pos,
                endpos = segments[2].Pos,
                filter = {ent, ply},
                mask = MASK_SOLID_BRUSHONLY,
            })
            
            ply.lerpedsegmenthit = LerpFT(0.1, ply.lerpedsegmenthit or 0, (1 - tr.Fraction))
            ply.oldhitnormal = LerpAngleFT(0.1, ply.oldhitnormal or tr.HitNormal:Angle(), tr.Hit and tr.HitNormal:Angle() or ply.oldhitnormal or Angle())
            
            if ply.lerpedsegmenthit > 0.01 and ply.oldhitnormal then
                local hitnormal = ply.oldhitnormal:Forward()
                local dist = 20--ply.segmentsl[2].Pos:Distance(ply.segmentsl[1].Pos)
                local new = hitnormal * dist * ply.lerpedsegmenthit * (math.sin(math.acos(hitnormal:Dot(tr.Normal)))) + segments[2].Pos

                segments[2].Pos = new
            end

            local newpos = hook.Run("IKPoleRightArm", ply, ent, segments[2].Pos, segments)

            if newpos then
                segments[2].Pos = newpos
            end

            ply.leftClicking = LerpFT(0.05, ply.leftClicking or 0, (ishgweapon(self) and hg.KeyDown(ply, IN_ATTACK)) and 1 or 0.05)

            local hand = ply_r_hand_matrix:GetTranslation()

            if false and !ishgweapon(self) and ply.organism and ply.organism.rarm and ply.organism.rarm > 0.99 then
                segments[3] = segments[3] or {Pos = hand, Len = limblength}
                segments[3].Pos = LerpVector(ply.leftClicking, segments[3].Pos + (-vector_up * 0.8 + eyeang:Forward() * 0.4 + ent:GetVelocity() / 400) * 0.5, hand)
            else
                segments[3] = {Pos = Lerp(1 - lerp_rh, ply.last_rh and ply.last_rh:GetTranslation() or segments[3].Pos, ply_r_hand_matrix_old and ply_r_hand_matrix_old:GetTranslation() or hand), Len = 12}
            end

            if lply:IsSuperAdmin() then
                for i = 2, #segments do
                    debugoverlay.Line(segments[i - 1].Pos, segments[i].Pos, 0, color_white, true)
                end
            end

            segments = solve(segments, 4)

            --[[if lply:IsSuperAdmin() then
                for i = 2, #segments do
                    debugoverlay.Line(segments[i - 1].Pos, segments[i].Pos, 0, color_white, true)
                end
            end--]]

            ply.segmentsr = segments
        end

        local new = -(-segments[3].Pos)

        ply_r_upperarm_matrix:SetTranslation(segments[1].Pos)
        ply_r_forearm_matrix:SetTranslation(segments[2].Pos)
        ply_r_hand_matrix:SetTranslation(new)


        local diff = (segments[2].Pos - segments[1].Pos):GetNormalized()
        local angrr = diff:Angle()
        local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
        local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
        angle3 = math.NormalizeAngle(angle3)
        local torsoright = eyeang.y + 120
    
        local q = Quaternion()
        q = q * Quaternion():SetAngleAxis(angrr.y, vecUpZ)
        q = q * Quaternion():SetAngleAxis(angrr.p, vecUpY)
        q = q * Quaternion():SetAngleAxis(-120 + angrr.y - eyeang.y + eyeang.r, vecUpX)

        local ang = q:Angle()

        ply_r_upperarm_matrix:SetAngles(ang)

        local diff = (segments[3].Pos - segments[2].Pos):GetNormalized()
        local angrr = diff:Angle()
        local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
        local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
        angle3 = math.NormalizeAngle(angle3)
        local torsoright = eyeang.y + 120
    
        local q = Quaternion()
        q = q * Quaternion():SetAngleAxis(angrr.y, vecUpZ)
        q = q * Quaternion():SetAngleAxis(angrr.p, vecUpY)
        q = q * Quaternion():SetAngleAxis(-120 - angrr.r + eyeang.r - math.NormalizeAngle((eyeang.y - angrr.y)) * (math.NormalizeAngle(angrr.p)) / 90, vecUpX)

        local ang = q:Angle()
        ply_r_forearm_matrix:SetAngles(ang)

        if false and ply.organism and ply.organism.rarm and ply.organism.rarm > 0.99 then
            local ang = ang//qt:Angle()
            ang:RotateAroundAxis(ang:Forward(), -95)
            ply_r_hand_matrix:SetAngles(LerpAngle(math_Clamp(ply.leftClicking * 2, 0, 1), ang, ply_r_hand_matrix:GetAngles()))
        end

        hg.bone_apply_matrix(ent, ply_r_upperarm_index, ply_r_upperarm_matrix, ply_r_forearm_index)
        hg.bone_apply_matrix(ent, ply_r_forearm_index, ply_r_forearm_matrix, ply_r_hand_index)
        hg.bone_apply_matrix(ent, ply_r_hand_index, ply_r_hand_matrix)

        if IsValid(ply.OldRagdoll) then
            hg.bone_apply_matrix(ply, ply_r_upperarm_index, ply_r_upperarm_matrix, ply_r_forearm_index)
            hg.bone_apply_matrix(ply, ply_r_forearm_index, ply_r_forearm_matrix, ply_r_hand_index)
            hg.bone_apply_matrix(ply, ply_r_hand_index, ply_r_hand_matrix)
        end

        local angrotate = math.NormalizeAngle(-eyeang.r + ply_r_hand_matrix:GetAngles().r + math.NormalizeAngle((eyeang.y - ply_r_hand_matrix:GetAngles().y)) * (math.NormalizeAngle(ply_r_hand_matrix:GetAngles().p)) / 90 + -90)
        
        local wrst = ply_r_ulna_index
        local wmat = wrst and ent:GetBoneMatrix(wrst)
        if wrst and wmat then
            ang:RotateAroundAxis(ang:Forward(), angrotate * 0.5 + -30)
            wmat:SetAngles(ang)
            ent:SetBoneMatrix(wrst, wmat)
        end

        local wrst = ply_r_wrist_index
        local wmat = wrst and ent:GetBoneMatrix(wrst)
        if wrst and wmat then
            ang:RotateAroundAxis(ang:Forward(), angrotate * 0.5 - 30)
            wmat:SetAngles(ang)
            ent:SetBoneMatrix(wrst, wmat)
        end
    end
    
    if lerp_lh != 0 then
        local segments = ply.segmentsl
        
        if shouldrebuild or not segments[3] then
            local old = segments[2] and ((segments[2].Pos - segments[1].Pos):GetNormalized() * 2) or vector_origin
            local eyeang = -(-eyeang)
            eyeang.p = math.NormalizeAngle(eyeang.p) * 0.5
            segments[1].Pos = ply_l_upperarm_matrix:GetTranslation()
            segments[1].Len = limblength
            segments[2].Pos = spinepos + eyeang:Right() * -25 - eyeang:Up() * 20
            segments[2].Len = limblength
            
            local tr = util.TraceLine({
                start = segments[1].Pos,
                endpos = segments[2].Pos,
                filter = {ent, ply},
                mask = MASK_SOLID_BRUSHONLY,
            })

            ply.lerpedsegmenthit2 = LerpFT(0.1, ply.lerpedsegmenthit2 or 0, (1 - tr.Fraction))
            
            ply.oldhitnormal2 = LerpAngleFT(0.1, ply.oldhitnormal2 or tr.HitNormal:Angle(), tr.Hit and tr.HitNormal:Angle() or ply.oldhitnormal2 or Angle())
            if ply.lerpedsegmenthit2 > 0.01 and ply.oldhitnormal2 then
                local hitnormal = ply.oldhitnormal2:Forward()
                local dist = 20--segments[2].Pos:Distance(segments[1].Pos)
                local new = hitnormal * dist * ply.lerpedsegmenthit2 * (math.sin(math.acos(hitnormal:Dot(tr.Normal)))) + segments[2].Pos

                segments[2].Pos = new
            end

            local newpos = hook.Run("IKPoleLeftArm", ply, ent, segments[2].Pos, segments)

            if newpos then
                segments[2].Pos = newpos
            end

            local hand = ply_l_hand_matrix:GetTranslation()
            local add = (hand - segments[1].Pos):GetNormalized() * 5 + eyeang:Right() * -5 + eyeang:Forward() * ((ply.lerp_hand or 0) - 0.5) * 10

            if ply.organism and ply.organism.larm and ply.organism.larm > 0.99 and ishgweapon(self) and !self.reload and ishgweapon(self) then
                segments[3] = segments[3] or {Pos = hand, Len = limblength}
                segments[3].Pos = LerpVector(!(ishgweapon(self) and self:IsPistolHoldType()) and 0.05 or 0.01, segments[3].Pos + (-vector_up * 0.6 + eyeang:Forward() * 0.4 + ((ishgweapon(self) and !self:IsPistolHoldType()) and eyeang:Right() * 0.7 or vector_origin) + ent:GetVelocity() / 400) * 0.5, hand)
            else
                segments[3] = {Pos = Lerp(1 - lerp_lh, ply.last_lh and ply.last_lh:GetTranslation() or segments[3].Pos, ply_l_hand_matrix_old and ply_l_hand_matrix_old:GetTranslation() or hand), Len = 12}
            end

            if lply:IsSuperAdmin() then
                for i = 2, #segments do
                    debugoverlay.Line(segments[i - 1].Pos, segments[i].Pos, 0, color_white, true)
                end
            end

            segments = solve(segments, 4)

            --[[if lply:IsSuperAdmin() then
                for i = 2, #segments do
                    debugoverlay.Line(segments[i - 1].Pos, segments[i].Pos, 0, color_white, true)
                end
            end]]
            
            ply.segmentsl = segments
        end

        local new = -(-segments[3].Pos)

        ply_l_upperarm_matrix:SetTranslation(segments[1].Pos)
        ply_l_forearm_matrix:SetTranslation(segments[2].Pos)
        ply_l_hand_matrix:SetTranslation(new)

        local diff = (segments[2].Pos - segments[1].Pos):GetNormalized()
        local angrr = diff:Angle()
        local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
        local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
        angle3 = math.NormalizeAngle(angle3)
        local torsoright = eyeang.y + 90
    
        local q = Quaternion()
        q = q * Quaternion():SetAngleAxis(angrr.y, vecUpZ)
        q = q * Quaternion():SetAngleAxis(angrr.p, vecUpY)
        q = q * Quaternion():SetAngleAxis(-30 + angrr.y - eyeang.y + eyeang.r, Vector(1, 0, 0))
        
        local ang = q:Angle()
        ply_l_upperarm_matrix:SetAngles(ang)

        local diff = (segments[3].Pos - segments[2].Pos):GetNormalized()
        local angrr = diff:Angle()
        local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
        local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
        angle3 = math.NormalizeAngle(angle3)
        local torsoright = eyeang.y + 180
    
        local q = Quaternion()
        q = q * Quaternion():SetAngleAxis(angrr.y, vecUpZ)
        q = q * Quaternion():SetAngleAxis(angrr.p, vecUpY)
        q = q * Quaternion():SetAngleAxis(-60 - angrr.r + eyeang.r - math.NormalizeAngle((eyeang.y - angrr.y)) * (math.NormalizeAngle(angrr.p)) / 90, Vector(1, 0, 0))

        local ang = q:Angle()

        ply_l_forearm_matrix:SetAngles(ang)

        if ply.organism and ply.organism.larm and ply.organism.larm > 0.99 and ishgweapon(self) and !self.reload and ishgweapon(self) then
            local ang = ang//qt:Angle()
            ang:RotateAroundAxis(ang:Forward(), 95)
            ply_l_hand_matrix:SetAngles(LerpAngle(0.5, ply_l_hand_matrix:GetAngles(), ang))
        end

        hg.bone_apply_matrix(ent, ply_l_upperarm_index, ply_l_upperarm_matrix, ply_l_forearm_index)
        hg.bone_apply_matrix(ent, ply_l_forearm_index, ply_l_forearm_matrix, ply_l_hand_index)
        hg.bone_apply_matrix(ent, ply_l_hand_index, ply_l_hand_matrix)

        if IsValid(ply.OldRagdoll) then
            hg.bone_apply_matrix(ply, ply_l_upperarm_index, ply_l_upperarm_matrix, ply_l_forearm_index)
            hg.bone_apply_matrix(ply, ply_l_forearm_index, ply_l_forearm_matrix, ply_l_hand_index)
            hg.bone_apply_matrix(ply, ply_l_hand_index, ply_l_hand_matrix)
        end

        local angrotate = math.NormalizeAngle(-eyeang.r + ply_l_hand_matrix:GetAngles().r + math.NormalizeAngle((eyeang.y - ply_l_hand_matrix:GetAngles().y)) * (math.NormalizeAngle(ply_l_hand_matrix:GetAngles().p)) / 90 - 45)

        local wrst = ply_l_ulna_index
        local wmat = wrst and ent:GetBoneMatrix(wrst)
        if wrst and wmat then
            ang:RotateAroundAxis(ang:Forward(), angrotate * 0.5 + 00)
            wmat:SetAngles(ang)
            ent:SetBoneMatrix(wrst, wmat)
        end

        local wrst = ply_l_wrist_index
        local wmat = wrst and ent:GetBoneMatrix(wrst)
        if wrst and wmat then
            ang:RotateAroundAxis(ang:Forward(), angrotate * 0.5 + 00)
            wmat:SetAngles(ang)
            ent:SetBoneMatrix(wrst, wmat)
        end
    end
    
    self.lhandik = false
    self.rhandik = false
end

hg.IKSolve = solve

function hg.Solve2PartIK(start_p, end_p, length0, length1, mat0, mat1, sign, torsomat, angs, ang)
    local length2 = (start_p - end_p):Length()

    if length0 + length1 < length2 then
        local add = length2 - length1 - length0
        --length0 = length0 + add * length0 / (length2 - add)
        --length1 = length1 + add * length1 / (length2 - add)
    end

    local prev_ang0 = Quaternion():SetMatrix(mat0)
    local prev_ang1 = Quaternion():SetMatrix(mat1)
    local angar = prev_ang1:Angle()

    local cosAngle0 = math_Clamp(((length2 * length2) + (length0 * length0) - (length1 * length1)) / (2 * length2 * length0), -1, 1)
    local angle0 = -math.deg(math.acos(cosAngle0))
    local cosAngle1 = math_Clamp(((length1 * length1) + (length0 * length0) - (length2 * length2)) / (2 * length1 * length0), -1, 1)
    local angle1 = -math.deg(math.acos(cosAngle1))
    local diff = end_p - start_p-- + lply:EyeAngles():Forward() * 555
    diff:Normalize()
    local angle2 = math.deg(math.atan2(-math.sqrt(diff.x * diff.x + diff.y * diff.y), diff.z)) - 90
    local angle3 = -math.deg(math.atan2(diff.x, diff.y)) - 90
    angle3 = math.NormalizeAngle(angle3)
    
    local diff2 = -torsomat:GetAngles():Forward()
    --debugoverlay.Line(start_p,start_p + diff2 * 10,0.1,color_white,true)
    --debugoverlay.Line(start_p,start_p + diff * 10,0.1,color_red,true)
    local axis = diff * 1
    axis:Normalize()
    
    local torsoang = torsomat:GetAngles()

    local Joint0 = Angle(angle0 + angle2, angle3, 0)

    local asdot = -vector_up:Dot(torsoang:Up())
    local diffa = math.deg(math.acos(asdot)) + (sign < 0 and -0 or 0)
    local diffa2 = 90 + (sign > 0 and -30 or 30)--math.deg(math.acos(asdot))
    
    local tors = torsoang:Up()
    local torsoright = -math.deg(math.atan2(tors.x, tors.y)) - 180 - 60 * sign
    
    torsoright = angs.y - angs.r + 120 * sign-- + (math.NormalizeAngle(angs.p) < 0 and math.NormalizeAngle(angs.p) or 0) * 1 * (sign < 0 and -0.5 or 0.5)// + 90// + -math.abs(math.NormalizeAngle(angs.p)) * sign * (angs.r - 90) / 90 * -2 + angs.r
    
    Joint0:RotateAroundAxis(Joint0:Forward(), diffa2 + 15)
    Joint0:RotateAroundAxis(axis, angle3 - torsoright)
    prev_ang0:SetAngle(Joint0)

    --debugoverlay.Line(start_p,start_p + -diff:Angle():Up() * 10,0.1,color_black,true)
    --debugoverlay.Line(start_p,start_p + torsoang:Up() * sign * 10,0.1,color_red,true)
    
    --render.DrawLine(start_p,start_p + -diff:Angle():Up() * 10,color_black, true)
    --render.DrawLine(start_p,start_p + torsoang:Up() * sign * 10,color_red, true)

    local Joint0 = prev_ang0:Angle():Forward() * length0
    //local diffa2 = ang[3] + 90

    local Joint1 = Angle(angle0 + angle2 + 180 + angle1, angle3, 0)
    Joint1:RotateAroundAxis(Joint1:Forward(), diffa2 + 30)// + angar[3] * (sign > 0 and 1 or 0) * (1 - math.abs(angar[1] / 90)))//+ ang[3] / 4 + 60)
    Joint1:RotateAroundAxis(axis, angle3 - torsoright)
    prev_ang1:SetAngle(Joint1)
    --prev_ang1:SetDirection(Joint1:Forward(), torsomat:GetAngles():Up() * 1)
    
    local Joint1 = prev_ang1:Angle():Forward() * length1

    local Joint0_F = start_p + Joint0
    local Joint1_F = Joint0_F + Joint1

    return Joint0_F, Joint1_F, prev_ang0:Angle(), prev_ang1:Angle()
end

function hg.FlashlightPos(ply)    
    if not ply:GetNetVar("flashlight", false) then
        if IsValid(ply.flashlight) then
            ply.flashlight:Remove()
        end

        return
    end

    if not ply:GetNetVar("Inventory") or not ply:GetNetVar("Inventory")["Weapons"] or not ply:GetNetVar("Inventory")["Weapons"]["hg_flashlight"] or ply.organism and ply.organism.larmamputated then
        if IsValid(ply.flashlight) then
            ply.flashlight:Remove()
        end
        
        if IsValid(ply.flmodel) then
            ply.flmodel:SetNoDraw(true)
        end

        return
    end
    
    local wep = ply:GetActiveWeapon()
    local flashlightwep

    if IsValid(wep) then
        local laser = wep.attachments and wep.attachments.underbarrel
        local attachmentData
        if (laser and not table.IsEmpty(laser)) or wep.laser then
            if laser and not table.IsEmpty(laser) then
                attachmentData = hg.attachments.underbarrel[laser[1]]
            else
                attachmentData = wep.laserData
            end
        end
        
        if attachmentData then flashlightwep = attachmentData.supportFlashlight end
    end

    if flashlightwep then if IsValid(ply.flashlight) then ply.flashlight:Remove() end return end -- может хуки добавить для подобной хрени
    
    local ent = ply.FakeRagdoll
	local rh,lh = ply:LookupBone("ValveBiped.Bip01_R_Hand"), ply:LookupBone("ValveBiped.Bip01_L_Hand")

	local rhmat = ply:GetBoneMatrix(rh)
	local lhmat = ply:GetBoneMatrix(lh)

    local headmat = ply:GetBoneMatrix(ply:LookupBone("ValveBiped.Bip01_Head1"))
	
    local veclh,lang
    if ply == lply and ply == GetViewEntity() then
        veclh,lang = hg.FlashlightTransform(ply)
    else
        veclh,lang = hg.FlashlightTransform(ply,false)
    end

	local rhmat,lhmat = ply:GetBoneMatrix(rh),ply:GetBoneMatrix(lh)

    if IsValid(ply.FakeRagdoll) then return end
    if not rhmat or not lhmat then return end
    if not ishgweapon(wep) or wep.reload then return end
	if ply.organism and ply.organism.larmamputated then return end

    if veclh and lang then
	    lhmat:SetTranslation(veclh)
	    lhmat:SetAngles(lang)
    end
    
	--hg.bone_apply_matrix(ply,rh,rhmat)
	--hg.bone_apply_matrix(ply,lh,lhmat)
end

local vec1 = Vector(0, 2, 0)
local vec2 = Vector(0, -2, 0)
local ang1 = Angle(-30,5,70)
local ang2 = Angle(-30,-5,110)
function hg.DragHands(ply,self)
    if not IsValid(ply) then return end
    	
    local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
    if !ply_spine_index then return end
    local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
    local wmpos = ply_spine_matrix:GetTranslation()

    local eyetr = hg.eyeTrace(ply)

	local ent = IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent") or IsValid(ply:GetNetVar("carryent2")) and ply:GetNetVar("carryent2")
	local pos = IsValid(ent) and ent:GetPos() or false
	local bon = ply:GetNetVar("carrybone",0) ~= 0 and ply:GetNetVar("carrybone",0) or ply:GetNetVar("carrybone2",0)
	local lpos = IsValid(ent) and ply:GetNetVar("carrypos",nil) or ply:GetNetVar("carrypos2",nil)
	--local twohands = (ply:GetNetVar("carrymass",0) ~= 0 and ply:GetNetVar("carrymass",0) or ply:GetNetVar("carrymass2",0)) > 15
	local wep = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon()
	local twohands = ply:GetNetVar("carrymass",0) > 15 or (!hg.CanUseLeftHand(ply) and wep and wep:GetClass() == "weapon_hands_sh")

	local norm
    local dist

    local TraceResult
    if IsValid(ent) then
		local bone = ent:TranslatePhysBoneToBone(bon)
		local wanted_pos = bone and ent:GetBoneMatrix(bone) or ent:GetPos()

        if lpos then
            if not ent:IsRagdoll()then
                wanted_pos = ent:LocalToWorld(lpos)
            elseif ismatrix(wanted_pos) then
                wanted_pos = LocalToWorld(lpos, angle_zero, wanted_pos:GetTranslation(), wanted_pos:GetAngles())
            end
        end
        dist = wanted_pos:Distance(ply_spine_matrix:GetTranslation())

		local start = ply_spine_matrix:GetTranslation()
		local len = (wanted_pos - start):Length()
		len = math.min(len,40)
        local tr = {}

		tr.start = start
		tr.endpos = start + (wanted_pos - start):GetNormalized() * len
		tr.filter = ply
		TraceResult = util.TraceLine(tr)
		pos = TraceResult.HitPos - TraceResult.Normal * 4
		norm = wanted_pos - ply:EyePos()
	end

	local rh,lh = ply:LookupBone("ValveBiped.Bip01_R_Hand"), ply:LookupBone("ValveBiped.Bip01_L_Hand")
	local rhmat,lhmat = ply:GetBoneMatrix(rh), ply:GetBoneMatrix(lh)
    
	if pos then
        local dot = (pos - ply_spine_matrix:GetTranslation()):GetNormalized():Dot(eyetr.Normal:Angle():Right())

		if wep and not ishgweapon(wep) then -- ЮЗЛЕСС ПРАТСИИИИ ПРАСТИИИИИИИИ
			hg.bone.Set(ply, "spine", vector_origin, Angle(0, 0, -dot * 20), "holding")
			hg.bone.Set(ply, "spine2", vector_origin, Angle(0, 0, -dot * 25), "holding2")
			hg.bone.Set(ply, "head", vector_origin, -Angle(0, 0, -dot * 30), "holding3")
		end
        --надо тогда и на сервере делать, а то будет различаться --!! не так уж и сильно различается

		--!! ломает аксесуары
        --local matang = ply_spine_matrix:GetAngles()
        --matang[2] = matang[2] - dot * 40
        --ply_spine_matrix:SetAngles(matang)
        --hg.bone_apply_matrix(ply, ply_spine_index, ply_spine_matrix)

		local amputee = ply.organism and ply.organism.larmamputated

		local posDot = (pos - ply_spine_matrix:GetTranslation()):GetNormalized():Dot(ply_spine_matrix:GetAngles():Forward()) * -50
		local posMul = math_Clamp(-(-posDot / 20), 0.1, 1.5)
		local posMul2 = math_Clamp(-posDot / 20, -1, 1)
		local posMul3 = math_Clamp((-posDot + 30) / 20, 1, 2)

		ang1 = Angle(-30 * posMul,5,70 * -posMul2)
		ang2 = Angle(-30 * posMul,-5,-120 * -posMul3)

        if twohands or amputee then

            local oldpos = rhmat:GetTranslation()
            --pos = pos + LerpFT(0.01,ply.oldposrh or (pos - oldpos),pos - oldpos)
            pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
            pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
            pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

            rhmat:SetTranslation(pos)

            if norm then
                --local min, max = ent:GetModelBounds()
                --local len = max:Distance(min)
                --local tr = util.TraceLine({start = ent:GetPos() + -TraceResult.HitNormal:Angle():Right() * (len), endpos = ent:GetPos() + -TraceResult.HitNormal:Angle():Right() * (len) + TraceResult.HitNormal:Angle():Right() * len, filter = {ply, Entity(0)}})
                --local pos = tr.HitPos
                local pos,newang = LocalToWorld(vec2,ang2,pos,norm:Angle())
                rhmat:SetTranslation(pos)
                rhmat:SetAngles(newang)
            end

            hg.bone_apply_matrix(ply,rh,rhmat)
            
            ply.oldposrh = pos - oldpos
            self.rhandik = true
        end

        if amputee then return end

        local oldpos = lhmat:GetTranslation()
        pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
        pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
        pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

        if norm then
            local pos,newang = LocalToWorld(twohands and vec1 or vector_origin,ang1,pos,norm:Angle())
            lhmat:SetTranslation(pos)
            lhmat:SetAngles(newang)
        end
        
        if hg.CanUseLeftHand(ply) then
            hg.bone_apply_matrix(ply,lh,lhmat)
        end
        ply.oldposlh = pos - oldpos
        
        self.lhandik = true
    end
end

function hg.DragRightHand(ply,self,pos,norm,anglh)
    if not IsValid(ply) then return end   	

	local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
	if !ply_spine_index then return end
	local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
	local wmpos = ply_spine_matrix:GetTranslation()

	--local ent = IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent") or IsValid(ply:GetNetVar("carryent2")) and ply:GetNetVar("carryent2")
	--local pos = IsValid(ent) and ent:GetPos() or false
	--local bon = ply:GetNetVar("carrybone",0) ~= 0 and ply:GetNetVar("carrybone",0) or ply:GetNetVar("carrybone2",0)
	--local lpos = IsValid(ent) and (ply:GetNetVar("carrypos",nil) and ent:LocalToWorld(ply:GetNetVar("carrypos",nil)) or ply:GetNetVar("carrypos2",nil) and ent:LocalToWorld(ply:GetNetVar("carrypos2",nil)))
	--local twohands = (ply:GetNetVar("carrymass",0) ~= 0 and ply:GetNetVar("carrymass",0) or ply:GetNetVar("carrymass2",0)) > 15
	
	local norm = norm

	local rh = ply:LookupBone("ValveBiped.Bip01_R_Hand")
	local rhmat = ply:GetBoneMatrix(rh)
    
    self.rhandik = true
    
	if pos then
        local oldpos = rhmat:GetTranslation()
        pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
        pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
        pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

        if norm then
            local pos,newang = LocalToWorld(vecZero, anglh or angZero,pos,norm:Angle())
            rhmat:SetTranslation(pos)
            rhmat:SetAngles(newang)
        end

        hg.bone_apply_matrix(ply,rh,rhmat)
        ply.oldposrh = pos - oldpos
    end
end

function hg.DragLeftHand(ply, self, pos, norm, anglh)
    if not IsValid(ply) then return end

	local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
	if !ply_spine_index then return end
	local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
	local wmpos = ply_spine_matrix:GetTranslation()

	--local ent = IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent") or IsValid(ply:GetNetVar("carryent2")) and ply:GetNetVar("carryent2")
	--local pos = IsValid(ent) and ent:GetPos() or false
	--local bon = ply:GetNetVar("carrybone",0) ~= 0 and ply:GetNetVar("carrybone",0) or ply:GetNetVar("carrybone2",0)
	--local lpos = IsValid(ent) and (ply:GetNetVar("carrypos",nil) and ent:LocalToWorld(ply:GetNetVar("carrypos",nil)) or ply:GetNetVar("carrypos2",nil) and ent:LocalToWorld(ply:GetNetVar("carrypos2",nil)))
	--local twohands = (ply:GetNetVar("carrymass",0) ~= 0 and ply:GetNetVar("carrymass",0) or ply:GetNetVar("carrymass2",0)) > 15
	
	local norm = norm

	local lh = ply:LookupBone("ValveBiped.Bip01_L_Hand")
	local lhmat = ply:GetBoneMatrix(lh)
    
    self.lhandik = true
    
	if pos then
        local oldpos = lhmat:GetTranslation()
        pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
        pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
        pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

        if norm then
            local pos,newang = LocalToWorld(vecZero, anglh or angZero,pos,norm:Angle())
            lhmat:SetTranslation(pos)
            lhmat:SetAngles(newang)
        end

        hg.bone_apply_matrix(ply,lh,lhmat)
        ply.oldposlh = pos - oldpos
    end
end

function hg.DragLeftHand_Ex(ply, self, pos, ang, anglh)
    if not IsValid(ply) then return end

	local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
	if !ply_spine_index then return end
	local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
	local wmpos = ply_spine_matrix:GetTranslation()

	local lh = ply:LookupBone("ValveBiped.Bip01_L_Hand")
	local lhmat = ply:GetBoneMatrix(lh)
    
    self.lhandik = true
    
	if pos then
        local oldpos = lhmat:GetTranslation()
        pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
        pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
        pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

        if ang then
            local pos,newang = LocalToWorld(vecZero, anglh or angZero,pos,ang)
            lhmat:SetTranslation(pos)
            lhmat:SetAngles(newang)
        end

        hg.bone_apply_matrix(ply,lh,lhmat)
        ply.oldposlh = pos - oldpos
    end
end

function hg.DragRightHand_Ex(ply, self, pos, ang, angrh)
    if not IsValid(ply) then return end

	local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
	if !ply_spine_index then return end
	local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
	local wmpos = ply_spine_matrix:GetTranslation()

	local rh = ply:LookupBone("ValveBiped.Bip01_R_Hand")
	local rhmat = ply:GetBoneMatrix(rh)
    
    self.rhandik = true
    
	if pos then
        local oldpos = rhmat:GetTranslation()
        pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
        pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
        pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

        if ang then
            local pos,newang = LocalToWorld(vecZero, angrh or angZero,pos,ang)
            rhmat:SetTranslation(pos)
            rhmat:SetAngles(newang)
        end

        hg.bone_apply_matrix(ply,rh,rhmat)
        ply.oldposrh = pos - oldpos
    end
end

function hg.DragHandsToPos(ply,self,pos,twohanded,twohanddist,norm,angrh,anglh)
    if not IsValid(ply) then return end
    	
    local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
    if !ply_spine_index then return end
    local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
    local wmpos = ply_spine_matrix:GetTranslation()

	local ply_spine_index = ply:LookupBone("ValveBiped.Bip01_Spine4")
	if !ply_spine_index then return end
	local ply_spine_matrix = ply:GetBoneMatrix(ply_spine_index)
	local wmpos = ply_spine_matrix:GetTranslation()

	--local ent = IsValid(ply:GetNetVar("carryent")) and ply:GetNetVar("carryent") or IsValid(ply:GetNetVar("carryent2")) and ply:GetNetVar("carryent2")
	--local pos = IsValid(ent) and ent:GetPos() or false
	--local bon = ply:GetNetVar("carrybone",0) ~= 0 and ply:GetNetVar("carrybone",0) or ply:GetNetVar("carrybone2",0)
	--local lpos = IsValid(ent) and (ply:GetNetVar("carrypos",nil) and ent:LocalToWorld(ply:GetNetVar("carrypos",nil)) or ply:GetNetVar("carrypos2",nil) and ent:LocalToWorld(ply:GetNetVar("carrypos2",nil)))
	--local twohands = (ply:GetNetVar("carrymass",0) ~= 0 and ply:GetNetVar("carrymass",0) or ply:GetNetVar("carrymass2",0)) > 15
	local twohands = twohanded
	
	local norm = norm

	local rh,lh = ply:LookupBone("ValveBiped.Bip01_R_Hand"), ply:LookupBone("ValveBiped.Bip01_L_Hand")
	local rhmat,lhmat = ply:GetBoneMatrix(rh),ply:GetBoneMatrix(lh)
    
    self.lhandik = true
    
	if pos then
        if twohanded then
            self.rhandik = true

            local oldpos = rhmat:GetTranslation()
            --pos = pos + LerpFT(0.01,ply.oldposrh or (pos - oldpos),pos - oldpos)
            pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
            pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
            pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

            rhmat:SetTranslation(pos)

            if norm then
                local pos,newang = LocalToWorld(Vector(0, -twohanddist or -5,0),angrh or Angle(0,0,180),pos,norm:Angle())
                rhmat:SetTranslation(pos)
                rhmat:SetAngles(newang)
            end
            
            hg.bone_apply_matrix(ply,rh,rhmat)
            ply.oldposrh = pos - oldpos
        end


        local oldpos = lhmat:GetTranslation()
        pos.x = math_Clamp(pos.x, oldpos.x - 38, oldpos.x + 38)
        pos.y = math_Clamp(pos.y, oldpos.y - 38, oldpos.y + 38)
        pos.z = math_Clamp(pos.z, oldpos.z - 38, oldpos.z + 38)

        if norm then
            local pos,newang = LocalToWorld(Vector(0,twohands and twohanddist or 5 or 0,0), anglh or angZero,pos,norm:Angle())
            lhmat:SetTranslation(pos)
            lhmat:SetAngles(newang)
        end

        hg.bone_apply_matrix(ply,lh,lhmat)
        ply.oldposlh = pos - oldpos
    end
end

local meta = FindMetaTable("Entity")
function meta:PullLHTowards(towards, timetopull, mdl, offsets, callback)

    local ply = hg.RagdollOwner(self) or self

    timer.Simple(timetopull, function()
        if !IsValid(ply) or !IsValid(ply:GetActiveWeapon()) or !callback then return end
        callback(ply:GetActiveWeapon())
    end)

end
