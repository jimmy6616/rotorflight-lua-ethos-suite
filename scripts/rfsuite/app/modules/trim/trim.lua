local labels = {}
local fields = {}

local triggerOverRide = false
local inOverRide = false
local lastChangeTime = os.clock()
local currentRollTrim
local currentRollTrimLast
local currentPitchTrim
local currentPitchTrimLast
local currentCollectiveTrim
local currentCollectiveTrimLast
local currentYawTrim
local currentYawTrimLast
local currentIdleThrottleTrim
local currentIdleThrottleTrimLast
local clear2send = true


local mspapi = {
    api = {
        [1] = "MIXER_CONFIG",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Roll trim %",                  mspapi = 1, apikey = "swash_trim_0"},
            {t = "Pitch trim %",                 mspapi = 1, apikey = "swash_trim_1"},
            {t = "Col. trim %",                  mspapi = 1, apikey = "swash_trim_2"},
            {t = "Tail Motor idle  %", mspapi = 1, apikey = "tail_motor_idle", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},
            {t = "Yaw. trim %",                  mspapi = 1, apikey = "tail_center_trim", enablefunction = function() return (rfsuite.session.tailMode == 0) end }
        }
    }                 
}



local function saveData()
    clear2send = true
    rfsuite.app.triggers.triggerSaveNoProgress = true
end

local function mixerOn(self)

    rfsuite.app.audio.playMixerOverideEnable = true

    for i = 1, 4 do
        local message = {
            command = 191, -- MSP_SET_MIXER_OVERRIDE
            payload = {i}
        }

        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 0)
        rfsuite.tasks.msp.mspQueue:add(message)

        if rfsuite.config.logMSP then
            local logData = "mixerOn: {" .. rfsuite.utils.joinTableItems(message.payload, ", ") .. "}"
            rfsuite.utils.log(logData,"info")
        end

    end



    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function mixerOff(self)

    rfsuite.app.audio.playMixerOverideDisable = true

    for i = 1, 4 do
        local message = {
            command = 191, -- MSP_SET_MIXER_OVERRIDE
            payload = {i}
        }
        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 2501)
        rfsuite.tasks.msp.mspQueue:add(message)

        if rfsuite.config.logMSP then
            local logData = "mixerOff: {" .. rfsuite.utils.joinTableItems(message.payload, ", ") .. "}"
            rfsuite.utils.log(logData,"info")
        end

    end



    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function postLoad(self)

    if rfsuite.session.tailMode == nil then
        local v = rfsuite.app.Page.values['MIXER_CONFIG']["tail_rotor_mode"]
        rfsuite.session.tailMode = math.floor(v)
        rfsuite.app.triggers.reload = true
        return
    end

    -- existing
    currentRollTrim = rfsuite.app.Page.fields[1].value
    currentPitchTrim = rfsuite.app.Page.fields[2].value
    currentCollectiveTrim = rfsuite.app.Page.fields[3].value

    if rfsuite.session.tailModeActive == 1 or rfsuite.session.tailModeActive == 2 then currentIdleThrottleTrim = rfsuite.app.Page.fields[4].value end

    if rfsuite.session.tailModeActive == 0 then currentYawTrim = rfsuite.app.Page.fields[4].value end
    rfsuite.app.triggers.closeProgressLoader = true
end

local function wakeup(self)

    -- filter changes to mixer - essentially preventing queue getting flooded	
    if inOverRide == true then

        currentRollTrim = rfsuite.app.Page.fields[1].value
        local now = os.clock()
        local settleTime = 0.85
        if ((now - lastChangeTime) >= settleTime) and rfsuite.tasks.msp.mspQueue:isProcessed() and clear2send == true then
            if currentRollTrim ~= currentRollTrimLast then
                currentRollTrimLast = currentRollTrim
                lastChangeTime = now
                rfsuite.utils.log("save trim","debug")
                self.saveData(self)
            end
        end

        currentPitchTrim = rfsuite.app.Page.fields[2].value
        local now = os.clock()
        local settleTime = 0.85
        if ((now - lastChangeTime) >= settleTime) and rfsuite.tasks.msp.mspQueue:isProcessed() and clear2send == true then
            if currentPitchTrim ~= currentPitchTrimLast then
                currentPitchTrimLast = currentPitchTrim
                lastChangeTime = now
                self.saveData(self)
            end
        end

        currentCollectiveTrim = rfsuite.app.Page.fields[3].value
        local now = os.clock()
        local settleTime = 0.85
        if ((now - lastChangeTime) >= settleTime) and rfsuite.tasks.msp.mspQueue:isProcessed() and clear2send == true then
            if currentCollectiveTrim ~= currentCollectiveTrimLast then
                currentCollectiveTrimLast = currentCollectiveTrim
                lastChangeTime = now
                self.saveData(self)
            end
        end

        if rfsuite.session.tailMode == 1 or rfsuite.session.tailMode == 2 then
            currentIdleThrottleTrim = rfsuite.app.Page.fields[4].value
            local now = os.clock()
            local settleTime = 0.85
            if ((now - lastChangeTime) >= settleTime) and rfsuite.tasks.msp.mspQueue:isProcessed() and clear2send == true then
                if currentIdleThrottleTrim ~= currentIdleThrottleTrimLast then
                    currentIdleThrottleTrimLast = currentIdleThrottleTrim
                    lastChangeTime = now
                    self.saveData(self)
                end
            end
        end

        if rfsuite.session.tailMode == 0 then
            currentYawTrim = rfsuite.app.Page.fields[4].value
            local now = os.clock()
            local settleTime = 0.85
            if ((now - lastChangeTime) >= settleTime) and rfsuite.tasks.msp.mspQueue:isProcessed() then
                if currentYawTrim ~= currentYawTrimLast then
                    currentYawTrimLast = currentYawTrim
                    lastChangeTime = now
                    self.saveData(self)
                end
            end
        end

    end

    if triggerOverRide == true then
        triggerOverRide = false

        if inOverRide == false then

            rfsuite.app.audio.playMixerOverideEnable = true

            rfsuite.app.ui.progressDisplay("Mixer override", "Enabling mixer override...")

            rfsuite.app.Page.mixerOn(self)
            inOverRide = true
        else

            rfsuite.app.audio.playMixerOverideDisable = true

            rfsuite.app.ui.progressDisplay("Mixer override", "Disabling mixer override...")

            rfsuite.app.Page.mixerOff(self)
            inOverRide = false
        end
    end

end

local function onToolMenu(self)

    local buttons = {{
        label = "                OK                ",
        action = function()

            -- we cant launch the loader here to se rely on the modules
            -- wakup function to do this
            triggerOverRide = true
            return true
        end
    }, {
        label = "CANCEL",
        action = function()
            return true
        end
    }}
    local message
    local title
    if inOverRide == false then
        title = "Enable mixer override"
        message = "Set all servos to their configured center position. \r\n\r\nThis will result in all values on this page being saved when adjusting the servo trim."
    else
        title = "Disable mixer override"
        message = "Return control of the servos to the flight controller."
    end

    form.openDialog({
        width = nil,
        title = title,
        message = message,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end

local function onNavMenu(self)

    if inOverRide == true or inFocus == true then
        rfsuite.app.audio.playMixerOverideDisable = true

        inOverRide = false
        inFocus = false

        rfsuite.app.ui.progressDisplay("Mixer override", "Disabling mixer override...")

        mixerOff(self)
        rfsuite.app.triggers.closeProgressLoader = true
    end

    rfsuite.app.ui.openMainMenu()

end

return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Trim",
    mixerOff = mixerOff,
    mixerOn = mixerOn,
    postLoad = postLoad,
    onToolMenu = onToolMenu,
    onNavMenu = onNavMenu,
    wakeup = wakeup,
    saveData = saveData,
    navButtons = {
        menu = true,
        save = true,
        reload = true,
        tool = true,
        help = true
    },
    API = {},
}
