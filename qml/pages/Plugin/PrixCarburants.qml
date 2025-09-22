import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.spritradar.Util 1.0

Plugin {
    id: page

    name: "FR - Prix Carburants"
    description: "https://www.prix-carburants.2aaz.fr/"
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
        req.open( "GET", url+"/stations/around/"+lat+","+lng+"?types=,R,A&responseFields=Fuels,Price,Hours")
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
                            if( o.Fuels[j]["shortName"] == type ) {
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

                        //if( price == 0 || open == false) continue
                        if( price == 0 ) continue

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

    function requestStation( id, stationName ) {
        stationBusy = true
        station = {}
        stationPage = pageStack.push( "../GasStation.qml", {stationId:id} )
        var req = new XMLHttpRequest()
        req.open( "GET", url+"/station/"+id+"?opendata=v1" )
        req.setRequestHeader("accept", "application/json")
        req.onreadystatechange = function() {
            if( req.readyState == 4 ) {
                try {
                    var st = JSON.parse( req.responseText )
                    //console.log( JSON.stringify(st))
                    var price = []; var service = []; var days = [];
                    /*for( var j = 0; j < st.prices.length; j++ ) {
                        try {
                            price[price.length] = { "title":qsTr(names[types.indexOf(st.prices[j].id)]), "price":st.prices[j].price, "sz":Theme.fontSizeLarge, "tf":true }
                           } catch( ex ) {
                            console.log( JSON.stringify(st))
                        }
                    }*/
                    for( var j = 0; j < st.prix.length; j++ ) {
                        try {
                            price[price.length] =  {
                                "title":st.prix[j]["nom"],
                                "price":st.prix[j]["valeur"],
                                "sz":Theme.fontSizeLarge,  "tf":true }
                           } catch( ex ) {
                            console.log( JSON.stringify(price))
                        }
                    }

                    /*for(var j = 0; j < st["Services"].length; j++ ) {
                        var entry  = { title:"", text:st["Services"][j] }
                        service.push(entry)
                    }*/
                    var optimes = []
                    if ( st["horaires"]["automate-24-24"] && st["horaires"]["automate-24-24"] ==="1") {
                       optimes = [ {title:qsTr("Daily") , text:"00.00-23.59"} ]
                    } else {
                        for( var i = 0; i < 7; i++ ) {
                            try {
                                optimes[optimes.length] =  {
                                    "title":st["horaires"]["jour"][i].nom,
                                    "text":
                                    st["horaires"]["jour"][i].horaire[0]["ouverture"] + " - " + st["horaires"]["jour"][i].horaire[0]["fermeture"],
                                     }
                               } catch( ex ) {
                                console.log( JSON.stringify(optimes))
                            }
                        }
                     /*optimes = [
                                 { title:qsTr("Daily"),
                                 "text":st["horaires"]["jour"][0].horaire["ouverture"]+"-"+st["horaires"]["jour"][0].horaire["fermeture"] ,
                                  title:qsTr("Except"), "text": "-" }
                     ]*/
                    }

                    console.log( JSON.stringify(st["horaires"]))

                    station = {
                       "stationName": stationName, //st["id"],
                        "stationID":st.id,
                        "stationAdress": {
                            "street": st.adresse,
                            "county": st.ville,
                            "country":"",//country,
                            "latitude":st["latitude"],
                            "longitude":st["longitude"],
                        },
                        "content": [
                            { "title":qsTr("Prices"), "items": price },
                            { "title":qsTr("Opening times"), "items":optimes },
                            //{ "title":qsTr("Services"), "items": service },
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
        req.setRequestHeader("accept", "application/json")
        req.onreadystatechange = function() {
            if( req.readyState == 4 ) {
                try {
                    var price = 0
                    var st = JSON.parse( req.responseText )
                    for( var j = 0; j < st.Fuels.length; j++ ) {
                        try {
                            price = st.Fuels[j]["Price"].value;

                           } catch( ex ) {
                            console.log( JSON.stringify(st))
                        }
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

