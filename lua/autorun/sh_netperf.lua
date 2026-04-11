local perfTable = {}
local bitTable = {}
local umsgTable = {}
local umsgBitTable = {}
local totalStartTime = 0
local running = false

local function applyWrap()
    netperf_net_Incoming = netperf_net_Incoming or net.Incoming
    local net_Incoming = netperf_net_Incoming

    netperf_usermessage_IncomingMessage = netperf_usermessage_IncomingMessage or usermessage.IncomingMessage
    local um_IncomingMessage = netperf_usermessage_IncomingMessage

    usermessage.IncomingMessage = function( name, msg )
        if not running then return um_IncomingMessage( name, msg ) end
        local bits = msg:GetNumBitsLeft()
        local start = SysTime()
        um_IncomingMessage( name, msg )
        local elapsed = SysTime() - start
        umsgTable[name] = ( umsgTable[name] or 0 ) + elapsed
        umsgBitTable[name] = ( umsgBitTable[name] or 0 ) + bits
    end

    function net.Incoming( len, client )
        local headerNum = net.ReadHeader()
        local strName = util.NetworkIDToString( headerNum )

        net_ReadHeader = net_ReadHeader or net.ReadHeader
        net.ReadHeader = function()
            return headerNum
        end

        bitTable[strName] = ( bitTable[strName] or 0 ) + len
        local start = SysTime()

        net_Incoming( len, client )

        local endtime = SysTime()
        perfTable[strName] = ( perfTable[strName] or 0 ) + ( endtime - start )

        net.ReadHeader = net_ReadHeader
    end
end

local nw2Table = {}
hook.Add( "EntityNetworkedVarChanged", "NetPerf", function( _ent, name, _oldval, _newval )
    if not running then return end

    nw2Table[name] = ( nw2Table[name] or 0 ) + 1
end )

concommand.Add( SERVER and "red_sv_netperf_start" or "red_cl_netperf_start", function( ply )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    totalStartTime = SysTime()
    table.Empty( perfTable )
    table.Empty( bitTable )
    table.Empty( umsgTable )
    table.Empty( umsgBitTable )
    table.Empty( nw2Table )

    applyWrap()
    running = true
    print( "Netperf started" )
end )

concommand.Add( SERVER and "red_sv_netperf_stop" or "red_cl_netperf_stop", function( ply )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    if not running then
        print( "Netperf isn't running." )
        return
    end

    running = false
    print( "Netperf netresults:\n" )

    if next( perfTable ) then
        print( "Netmessages Sorted by time:\n" )
        local perfstr = ""
        for k, v in SortedPairsByValue( perfTable, true ) do
            perfstr = perfstr .. k .. " - " .. v .. "s - " .. bitTable[k] .. " bits\n"
        end
        print( perfstr )

        print( "Netmessages Sorted by bits:\n" )
        local bitstr = ""
        for k, v in SortedPairsByValue( bitTable, true ) do
            bitstr = bitstr .. k .. " - " .. v .. " bits - " .. perfTable[k] .. "s\n"
        end
        print( bitstr )
    end

    if next( nw2Table ) then
        print( "NW2 Sorted by count:\n" )
        for k, v in SortedPairsByValue( nw2Table, true ) do
            print( "NW2: " .. k .. " - " .. v .. " times" )
        end
        print( "" )
    end

    if next( umsgTable ) then
        print( "Usermessages Sorted by time:\n" )
        local umsgstr = ""
        for k, v in SortedPairsByValue( umsgTable, true ) do
            umsgstr = umsgstr .. k .. " - " .. v .. "s - " .. ( umsgBitTable[k] or 0 ) .. " bits\n"
        end
        print( umsgstr )

        print( "Usermessages Sorted by bits:\n" )
        local umsgbitstr = ""
        for k, v in SortedPairsByValue( umsgBitTable, true ) do
            umsgbitstr = umsgbitstr .. k .. " - " .. v .. " bits - " .. ( umsgTable[k] or 0 ) .. "s\n"
        end
        print( umsgbitstr )
    end

    print( "Time ran: " .. ( SysTime() - totalStartTime ) .. "s" )

    net.Incoming = netperf_net_Incoming
    net.ReadHeader = net_ReadHeader
    usermessage.IncomingMessage = netperf_usermessage_IncomingMessage
end )
