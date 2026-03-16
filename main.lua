local AIMod = RegisterMod("BotCoop_Definitivo", 1)

local moveX = {0, 0, 0, 0, 0}
local moveY = {0, 0, 0, 0, 0}
local shootX = {0, 0, 0, 0, 0}
local shootY = {0, 0, 0, 0, 0}

local function moveTowards(botIndex, pos, target, tolerance)
    if target.X > pos.X + tolerance then moveX[botIndex] = 1
    elseif target.X < pos.X - tolerance then moveX[botIndex] = -1 end

    if target.Y > pos.Y + tolerance then moveY[botIndex] = 1
    elseif target.Y < pos.Y - tolerance then moveY[botIndex] = -1 end
end

-- ============================================================================
-- 1. EL COMUNICADOR CON PYTHON (Para que la IA hable)
-- ============================================================================
function AIMod:ExportGameState()
    if Game():GetFrameCount() % 30 == 0 then
        if Game():GetNumPlayers() < 1 then return end
        local p1 = Isaac.GetPlayer(0)
        if not p1 then return end

        local roomName = Game():GetLevel():GetCurrentRoomDesc().Data.Name
        local itemDetectado = "Ninguno"
        local numEnemigos = 0
        local hayJefe = "No"

        for _, ent in ipairs(Isaac.GetRoomEntities()) do
            if ent.Type == EntityType.ENTITY_PICKUP and ent.Variant == PickupVariant.PICKUP_COLLECTIBLE then
                local itemConfig = Isaac.GetItemConfig():GetCollectible(ent.SubType)
                if itemConfig then itemDetectado = itemConfig.Name end
            end
            if ent:IsActiveEnemy() and ent:IsVulnerableEnemy() then
                numEnemigos = numEnemigos + 1
                if ent:IsBoss() then hayJefe = "Si" end
            end
        end

        local hp = tostring(p1:GetHearts())
        local datos = '{"jugador_hp": ' .. hp .. ', "sala_actual": "' .. roomName .. '", "items_visibles": "' .. itemDetectado .. '", "enemigos_vivos": ' .. numEnemigos .. ', "hay_jefe": "' .. hayJefe .. '"}'
        Isaac.DebugString("BOTCOOP_IA_DATOS:" .. datos)
    end
end
AIMod:AddCallback(ModCallbacks.MC_POST_UPDATE, AIMod.ExportGameState)

-- ============================================================================
-- 2. El cerebro y movimiento fluido
-- ============================================================================
function AIMod:BrainTick()
    local p1 = Isaac.GetPlayer(0)
    if not p1 then return end
    local room = Game():GetRoom()

    for i = 1, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        
        if player and player.InitSeed ~= p1.InitSeed then
            local botIndex = i + 1
            moveX[botIndex] = 0; moveY[botIndex] = 0
            shootX[botIndex] = 0; shootY[botIndex] = 0

            if player.FrameCount > 5 then
                player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_HOMING
            end

            local closestEnemy = nil
            local closestDist = 9999
            local closestPickup = nil
            local pickupDist = 9999
            local avoidRepulsionX, avoidRepulsionY = 0, 0

            local commandGrab = Input.IsButtonPressed(Keyboard.KEY_J, 0)

            -- FASE 1: ESCÁNER DE ENTIDADES VIVAS
            for _, ent in ipairs(Isaac.GetRoomEntities()) do
                local dist = player.Position:Distance(ent.Position)
                
                -- Enemigos
                if ent:IsVulnerableEnemy() and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
                    if dist < closestDist then closestDist = dist; closestEnemy = ent end
                end
                
                -- Ítems
                if ent.Type == EntityType.ENTITY_PICKUP then
                    if dist < pickupDist then pickupDist = dist; closestPickup = ent end
                    if ent.Variant == PickupVariant.PICKUP_COLLECTIBLE then
                        if not commandGrab and dist < 65 then
                            avoidRepulsionX = avoidRepulsionX - (ent.Position.X - player.Position.X) * 1.5
                            avoidRepulsionY = avoidRepulsionY - (ent.Position.Y - player.Position.Y) * 1.5
                        end
                    end
                end
                
                -- Fogatas (¡CON LÓGICA INTELIGENTE Y SIN ERRORES!)
                if ent.Type == EntityType.ENTITY_FIREPLACE then
                    -- Al ser una Entidad, le preguntamos si está "muerta" (apagada)
                    local estaPrendida = not ent:IsDead() 
                    local esAzulOMorada = (ent.Variant == 1 or ent.Variant == 2)
                    
                    if room:IsClear() and estaPrendida and not esAzulOMorada then
                        -- Si la sala está limpia y es fuego normal, lo marcamos como enemigo
                        if dist < closestDist then closestDist = dist; closestEnemy = ent end
                    elseif estaPrendida and dist < 45 then
                        -- Si está prendida (cualquier color) y estamos cerca, nos alejamos
                        avoidRepulsionX = avoidRepulsionX - (ent.Position.X - player.Position.X) * 2
                        avoidRepulsionY = avoidRepulsionY - (ent.Position.Y - player.Position.Y) * 2
                    end
                end

                -- Peligros móviles
                if ent.Type == EntityType.ENTITY_PROJECTILE and dist < 60 then
                    avoidRepulsionX = avoidRepulsionX - (ent.Position.X - player.Position.X) * 3
                    avoidRepulsionY = avoidRepulsionY - (ent.Position.Y - player.Position.Y) * 3
                end
                if ent.Type == EntityType.ENTITY_BOMB and dist < 120 then
                    avoidRepulsionX = avoidRepulsionX - (ent.Position.X - player.Position.X) * 4
                    avoidRepulsionY = avoidRepulsionY - (ent.Position.Y - player.Position.Y) * 4
                end
            end

            -- FASE 1.5: ESCÁNER DE GEOMETRÍA FIJA (Cacas y Rocas)
            local playerGridIndex = room:GetGridIndex(player.Position)
            local width = room:GetGridWidth()
            local checkIndices = {
                playerGridIndex, playerGridIndex - 1, playerGridIndex + 1,
                playerGridIndex - width, playerGridIndex + width,
                playerGridIndex - width - 1, playerGridIndex - width + 1,
                playerGridIndex + width - 1, playerGridIndex + width + 1
            }
            
            for _, idx in ipairs(checkIndices) do
                local gridEnt = room:GetGridEntity(idx)
                if gridEnt then
                    local gType = gridEnt:GetType()
                    local gPos = room:GetGridPosition(idx)
                    local dist = player.Position:Distance(gPos)
                    
                    if not player.CanFly then
                        local isObstacle = false
                        
                        -- Evaluar caca inteligente
                        if gType == GridEntityType.GRID_POOP then
                            if gridEnt:GetVariant() == 1 or gridEnt.State ~= 1000 then isObstacle = true end
                        -- Evaluar rocas y pozos
                        elseif gType == GridEntityType.GRID_ROCK or gType == GridEntityType.GRID_ROCKB or 
                               gType == GridEntityType.GRID_ROCK_ALT or gType == GridEntityType.GRID_ROCK_BOMB or 
                               gType == GridEntityType.GRID_ROCK_SPIKED or gType == GridEntityType.GRID_ROCK_SS or 
                               gType == GridEntityType.GRID_PIT or gType == GridEntityType.GRID_SPIKES or 
                               gType == GridEntityType.GRID_SPIKES_ONOFF then
                            isObstacle = true
                        end
                        
                        -- Si es obstáculo real, aplicamos repulsión (Distancia bajada de 45 a 38 para no trabarse)
                        if isObstacle and dist < 38 then
                            avoidRepulsionX = avoidRepulsionX - (gPos.X - player.Position.X) * 2.5
                            avoidRepulsionY = avoidRepulsionY - (gPos.Y - player.Position.Y) * 2.5
                        end
                    end
                end
            end

            local isAttacking = false

            -- FASE 2: PRIORIDADES DE MOVIMIENTO VIRTUAL
            if closestPickup and commandGrab then
                moveTowards(botIndex, player.Position, closestPickup.Position, 0)
            elseif math.abs(avoidRepulsionX) > 0 or math.abs(avoidRepulsionY) > 0 then
                moveX[botIndex] = avoidRepulsionX > 0 and 1 or (avoidRepulsionX < 0 and -1 or 0)
                moveY[botIndex] = avoidRepulsionY > 0 and 1 or (avoidRepulsionY < 0 and -1 or 0)
            elseif closestEnemy then
                isAttacking = true
                local xdiff = math.abs(closestEnemy.Position.X - player.Position.X)
                local ydiff = math.abs(closestEnemy.Position.Y - player.Position.Y)

                if closestDist > 220 then
                    moveTowards(botIndex, player.Position, closestEnemy.Position, 0)
                elseif closestDist < 85 then
                    moveX[botIndex] = (closestEnemy.Position.X > player.Position.X) and -1 or 1
                    moveY[botIndex] = (closestEnemy.Position.Y > player.Position.Y) and -1 or 1
                else
                    if xdiff > ydiff then
                        if closestEnemy.Position.Y > player.Position.Y + 10 then moveY[botIndex] = 1
                        elseif closestEnemy.Position.Y < player.Position.Y - 10 then moveY[botIndex] = -1 end
                    else
                        if closestEnemy.Position.X > player.Position.X + 10 then moveX[botIndex] = 1
                        elseif closestEnemy.Position.X < player.Position.X - 10 then moveX[botIndex] = -1 end
                    end
                end
            else
                if player.Position:Distance(p1.Position) > 60 then
                    moveTowards(botIndex, player.Position, p1.Position, 20)
                end
            end

            -- FASE 3: LÓGICA DE APUNTADO
            if isAttacking and closestEnemy then
                local xdiff = math.abs(closestEnemy.Position.X - player.Position.X)
                local ydiff = math.abs(closestEnemy.Position.Y - player.Position.Y)
                local shoottolerance = 35

                if ydiff < shoottolerance and ydiff < xdiff then
                    if closestEnemy.Position.X > player.Position.X then shootX[botIndex] = 1 else shootX[botIndex] = -1 end
                end
                if xdiff < shoottolerance and xdiff < ydiff then
                    if closestEnemy.Position.Y > player.Position.Y then shootY[botIndex] = 1 else shootY[botIndex] = -1 end
                end
            end
        end
    end
end
AIMod:AddCallback(ModCallbacks.MC_POST_UPDATE, AIMod.BrainTick)

-- ============================================================================
-- 3. Cambio de inputs y tears fantasmas
-- ============================================================================
function AIMod:OnInput(entity, inputHook, buttonAction)
    if entity == nil then return nil end
    local player = entity:ToPlayer()
    local p1 = Isaac.GetPlayer(0)

    if player and p1 and player.InitSeed ~= p1.InitSeed then
        local botIndex = -1
        for i = 1, Game():GetNumPlayers() - 1 do
            if Isaac.GetPlayer(i).InitSeed == player.InitSeed then botIndex = i + 1 break end
        end
        if botIndex == -1 then return nil end

-- Hacemos que el bot escuche las teclas F5 (Bomba), F6 (Activo) y F7 (Carta)
        local pressBomb = Input.IsButtonPressed(Keyboard.KEY_F5, 0)
        local pressItem = Input.IsButtonPressed(Keyboard.KEY_F6, 0)
        local pressCard = Input.IsButtonPressed(Keyboard.KEY_F7, 0)

        if buttonAction == ButtonAction.ACTION_BOMB then
            if inputHook == InputHook.GET_ACTION_VALUE then return pressBomb and 1.0 or 0.0 end
            return pressBomb
        elseif buttonAction == ButtonAction.ACTION_ITEM then
            if inputHook == InputHook.GET_ACTION_VALUE then return pressItem and 1.0 or 0.0 end
            return pressItem
        elseif buttonAction == ButtonAction.ACTION_PILLCARD then
            if inputHook == InputHook.GET_ACTION_VALUE then return pressCard and 1.0 or 0.0 end
            return pressCard
        elseif buttonAction == ButtonAction.ACTION_DROP then
            -- Seguir bloqueando que tire sus trinkets al piso por error
            if inputHook == InputHook.GET_ACTION_VALUE then return 0.0 end
            return false
        end

        if inputHook == InputHook.GET_ACTION_VALUE then
            if buttonAction == ButtonAction.ACTION_LEFT then return moveX[botIndex] == -1 and 1.0 or 0.0 end
            if buttonAction == ButtonAction.ACTION_RIGHT then return moveX[botIndex] == 1 and 1.0 or 0.0 end
            if buttonAction == ButtonAction.ACTION_UP then return moveY[botIndex] == -1 and 1.0 or 0.0 end
            if buttonAction == ButtonAction.ACTION_DOWN then return moveY[botIndex] == 1 and 1.0 or 0.0 end

            if buttonAction == ButtonAction.ACTION_SHOOTLEFT then return shootX[botIndex] == -1 and 1.0 or 0.0 end
            if buttonAction == ButtonAction.ACTION_SHOOTRIGHT then return shootX[botIndex] == 1 and 1.0 or 0.0 end
            if buttonAction == ButtonAction.ACTION_SHOOTUP then return shootY[botIndex] == -1 and 1.0 or 0.0 end
            if buttonAction == ButtonAction.ACTION_SHOOTDOWN then return shootY[botIndex] == 1 and 1.0 or 0.0 end
            return 0.0
        end

        if inputHook == InputHook.IS_ACTION_PRESSED then
            if buttonAction == ButtonAction.ACTION_SHOOTLEFT then return shootX[botIndex] == -1 end
            if buttonAction == ButtonAction.ACTION_SHOOTRIGHT then return shootX[botIndex] == 1 end
            if buttonAction == ButtonAction.ACTION_SHOOTUP then return shootY[botIndex] == -1 end
            if buttonAction == ButtonAction.ACTION_SHOOTDOWN then return shootY[botIndex] == 1 end
        end
    end
end
AIMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, AIMod.OnInput)

function AIMod:OnItemCollision(pickup, collider, low)
    local player = collider:ToPlayer()
    local p1 = Isaac.GetPlayer(0)
    
    if player and p1 and player.InitSeed ~= p1.InitSeed then
        if not Input.IsButtonPressed(Keyboard.KEY_J, 0) then return false end
    end
end
AIMod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, AIMod.OnItemCollision)

-- ============================================================================
-- 4. SPAWN CON LA B AL AZAR
-- ============================================================================
function AIMod:OnCmdSpawn()
    if Input.IsButtonTriggered(Keyboard.KEY_B, 0) then
        if Game():GetNumPlayers() < 2 then
            local chars = {0, 1, 2, 3, 4, 5, 6, 7, 10, 14, 15, 16}
            Isaac.ExecuteCommand("addplayer " .. tostring(chars[math.random(#chars)]))
        end
    end
end
AIMod:AddCallback(ModCallbacks.MC_POST_UPDATE, AIMod.OnCmdSpawn)