import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.spritradar.Util 1.0

Plugin {
    id: page

    name: "FR - Prix Carburants"
    description: "https://www.prix-carburants.gouv.fr/"
    units: { "currency":"€", "distance": "km" }
    countryCode: "fr"
    //property string url: "http://harbour-spritradar-fork.w4f.eu/fr/"
    property string url: "https://api.prix-carburants.2aaz.fr"
    type: "e10"
    types: ["Gazole", "SP95", "SP95-E10", "E85", "GPLc", "SP98"]
    names: [qsTr("Gazole"), qsTr("SP95"), qsTr("E10"), qsTr("E85"), qsTr("GPLc"), qsTr("SP98")]

    function betweenHours(h0, h1) {
      var now = new Date();
      var mins = now.getHours()*60 + now.getMinutes();
      return toMins(h0) <= mins && mins <= toMins(h1);
    }
    settings: Settings {
        name: "PrixCarburants"

        function save() {
            setValue( "radius", searchRadius )
            setValue( "type", type )
            setValue( "sort", main.sort )
            setValue( "gps", useGps )
            setValue( "address", address )
        }
        function load() {
            try {
                searchRadius = getValue( "radius" )
                type = getValue( "type" )
                main.sort = getValue( "sort" )
                useGps = JSON.parse( getValue( "gps" ) )
                address = getValue( "address" )
                favs.load()
            }
            catch(e) {
console.log(e.message)
                assign()
                load()
            }
        }
        function assign() {
            setValue( "radius", 1 )
            setValue( "type", "GPR" )
            setValue( "sort", main.sort )
            setValue( "gps", false )
            setValue( "address", "" )
        }
    }

    function prepare() {
        settings.load()
        pluginReady = true
    }

    function requestItems() {
        prepareItems()
        if( useGps ) getItems( latitude, longitude )
        else getItemsByAddress(getItems)
    }

    function getItems( lat, lng ) {
        errorCode = 0
        itemsBusy = true
        items.clear()
        coverItems.clear()
        var now = new Date()
        var day = now.getDay()
        var req = new XMLHttpRequest()
        // search radius is now via a header  -H 'Range: m=5000-7000'
        req.open( "GET", url+"/stations/around/"+lat+","+lng+"?types=R,A&responseFields=Fuels,Price,Hours")
        req.setRequestHeader("accept", "application/json")
        req.setRequestHeader("Range", "m=100-"+searchRadius*1000)
        req.onreadystatechange = function() {
            if( req.readyState == 4 ) {
                try {
                    var x = JSON.parse( req.responseText )
                    for( var i = 0; i < x.length; i++ ) {
                        var o = x[i]
                        var price = 0
                        var open = false
                        console.log(o.type)
                        for( var j = 0; j < o.Fuels.length; j++ ) {
                            //console.log(o.Fuels[0]["short_name"])
                            if( o.Fuels[j]["short_name"] == type ) {
                                price = o.Fuels[j]["Price"]["value"]
                            }
                        }
                        try {
                            if( o.Hours["Days"][day-1]["status"] == "open" ) {
                                open = true
                            }
                        } catch(e) {
                            console.log(e.message)
                        }

                        if( price == 0 || open == false) continue

                        var itm = {
                            "stationID": o.id,
                            "stationName": o["Brand"]["name"],
                            "stationPrice": price,
                            "stationAdress": o["Address"]["street_line"],
                            "stationDistance": o.distance,
                            "customMessage": !open?qsTr("Closed"):qsTr("Open")
                        }
                        items.append( itm )
                    }
                    sort()
                    itemsBusy = false
                    errorCode = items.count < 1 ? 1 : 0
                }
                catch(e) {
console.log(e.message)
                    items.clear()
                    itemsBusy = false
                    errorCode = 3
                }
            }
        }
        req.send()
    }

    function requestStation( id ) {
        stationBusy = true
        station = {}
        stationPage = pageStack.push( "../GasStation.qml", {stationId:id} )
        var req = new XMLHttpRequest()
        req.open( "GET", url+"/station/"+id )
        req.setRequestHeader("accept", "application/json")
        req.onreadystatechange = function() {
            if( req.readyState == 4 ) {
                try {

                    var st = JSON.parse( req.responseText )
                    var price = []; var service = []
                    /*for( var j = 0; j < st.prices.length; j++ ) {
                        try {
                            price[price.length] = { "title":qsTr(names[types.indexOf(st.prices[j].id)]), "price":st.prices[j].price, "sz":Theme.fontSizeLarge, "tf":true }
                           } catch( ex ) {
                            console.log( JSON.stringify(st))
                        }
                    }*/
                    for( var j = 0; j < st.Fuels.length; j++ ) {
                        try {
                            price[price.length] =  {
                                "title":st.Fuels[j]["short_name"],
                                "price":st.Fuels[j]["Price"].value,
                                "sz":Theme.fontSizeLarge,  "tf":true }
                           } catch( ex ) {
                            console.log( JSON.stringify(st))
                        }
                    }

                    for(var j = 0; j < st["Services"].length; j++ ) {
                        var entry  = { title:"", text:st["Services"][j] }
                        service.push(entry)
                    }
                    var optimes = [
                                 { title:qsTr("Daily"),
                                 "text":st["Hours"]["Days"][0]["TimeSlots"][0].opening_time+"-"+st["Hours"]["Days"][0]["TimeSlots"][0].closing_time },
                                 { title:qsTr("Except"), "text": "-" } ]
                    station = {
                       "stationName": st["Brand"]["name"],
                        "stationID":st.id,
                        "stationAdress": {
                            "street": st["Address"]["street_line"],
                            "county": st["Address"]["city_line"],
                            "country":"",//country,
                            "latitude":st["Coordinates"]["latitude"],
                            "longitude":st["Coordinates"]["longitude"],
                        },
                        "content": [
                            { "title":qsTr("Opening times"), "items":optimes },
                            { "title":qsTr("Prices"), "items": price },
                            { "title":qsTr("Services"), "items": service },
                        ]
                    }
                }
                catch(e) {
                    console.log( e.message )
                    stationPage.station = {}
                    stationBusy = false
                }
                stationPage.station = station
                stationBusy = false
            }
        }
        req.send()
    }

    function getPriceForFav( id ) {
        var req = new XMLHttpRequest()
        req.open( "GET", url+"/station/"+id )
        req.onreadystatechange = function() {
            if( req.readyState == 4 ) {
                try {
                    var o = JSON.parse( req.responseText )
                    var price = 0
                        for( var j = 0; j < o.prices.length; j++ ) {
                            if( o.prices[j].id == type ) price = o.prices[j].price
                        }
                    if( price == 0) return
                    setPriceForFav( id, price )
                }
                catch(e) {
console.log(e.message)
                }
            }
        }
        req.send()
    }

    radiusSlider {
        maximumValue: 25
    }

    content: Component {
        Column {}
    }
}

