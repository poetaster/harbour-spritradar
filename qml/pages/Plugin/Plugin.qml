import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.spritradar.Util 1.0

/*

  France: http://www.prix-carburants.gouv.fr/mobile/
  Netherlands: http://www.anwb.nl/pois/


  Format for items:
    [
        ...,
        {
            "stationID": "",
            "stationName": "Cheaptank",
            "stationPrice": 1.111,
            "stationAdress": "Somestreet 1, 12345 Strangeville[, Country]",
            "stationDistance": 2.2,
        },
        ...
    ]
  Format for station
    {
        "stationID":"",
        "stationName":"",
        "stationAdress": {
            "street":"Somestreet 1",
            "county":"Strangeville",
            "country":"Country"
            "latitude":100.1210,
            "longitude":56.3432
        }
        "content": [
            {
                "title":"Prices"
                "items": [
                    ...
                    { "tile":"Gasoline", ["text":null, ]"price": 1.111 },
                    ...
                ]
            },
            {
                "title":"Info"
                "items": [
                    ...
                    { "tile":"State", "text":"Closed"[, "price":null] },
                    ...
                ]
            },
            ...
        ]
    }

*/
Dialog {
    id: page
    clip: true
    allowedOrientations: Orientation.All
    onStatusChanged: if( status === PageStatus.Deactivating) { if( doSearch) {doSearch = false; selectedPlugin.requestItems(); settings.save()} }
    onAccepted: doSearch = true
    acceptDestination: list
    acceptDestinationAction: PageStackAction.Pop

    property ListModel items: ListModel{}
    property ListModel coverItems: ListModel{}
    property variant station;
    property bool itemsBusy: false
    property bool stationBusy: false
    property int errorCode: 0
    property bool doSearch: false
    property bool pluginReady: false
    property Settings settings: Settings{}
    property Component content;
    property Page stationPage;
    property alias contentItem: contentWrapper.item
    property string name;
    property string description;
    property variant units: { "currency":"", "distance": "" }
    property string countryCode: ""
    property bool supportsFavs: true

    onPluginReadyChanged: if( pluginReady ) requestItems()

    function requestItems() {
        busy = true;
    }
    function requestStation( id ) {
        busy = true;
    }
    function getNearbyStations( station ) {
        busy = true;
    }
    function getPriceForFav( id ) {
        return 0
    }
    function setPriceForFav( id, price ) {
        for( var i = 0; i<favs.stations.count; i++ )
            if( favs.stations.get(i).id == id )
                favs.stations.setProperty( i, "stationPrice", price )
    }

    function prepare() {
        pluginReady = true
    }
    function prepareItems() {
        errorCode = 0
        itemsBusy = true
        items.clear()
        coverItems.clear()
    }
    function getItemsByAddress(callback) {
        var req = new XMLHttpRequest()
        req.open( "GET", "https://nominatim.openstreetmap.org/search?q="+address+"&format=json&limit=1&accept-language="+countryCode+"&countrycodes="+countryCode )
        req.setRequestHeader("user-agent", "harbour-spritradar/2.11")
        req.setRequestHeader("referer", "harbour-spritradar/2.11")
        req.onreadystatechange = function() {
            if( req.readyState == 4 && !useGps ) {
                try {
                    var x = JSON.parse( req.responseText )
                    address = x[0].display_name
                    callback( x[0].lat, x[0].lon )
                }
                catch(e) {
console.log(e.message)
                    items.clear()
                    coverItems.clear()
                    itemsBusy = false
                    errorCode = 2
                }
            }
        }
        req.send()
    }

    function sort() {
        var list = []
        for( var i = 0; i<items.count; i++ ) {
            var o = items.get(i)
            list[list.length] = {
                "stationID": o.stationID,
                "stationName": o.stationName,
                "stationPrice": o.stationPrice,
                "stationAdress": o.stationAdress,
                "stationDistance": o.stationDistance,
                "customMessage": o.customMessage
            }
        }
        if( main.sort!="price") list = qmSort( "dist",  qmSort( "price", list ).reverse() )
        else                    list = qmSort( "price", qmSort( "dist",  list ).reverse() )
        items.clear()
        for( i = 0; i<list.length&&i<50; i++ ) {
            items.append(list[i])
        }
        createCoverItems()
    }

    function createCoverItems() {
        coverItems.clear()
        for( var i = 0; i<items.count&&i<6; i++ ) {
            coverItems.append(items.get(i))
        }
    }



    function timeSince( timestamp ) {
        var ago = _getAgo( timestamp )
        return ago[0]?qsTr("%1 ago").arg(ago[1]):qsTr("in %1").arg(ago[1])
    }
    function _getAgo( timestamp ) {
        var now = Date.now()
        var ago = now > timestamp
        var time = new Date( Math.abs( now - timestamp ) )
        if( time.getFullYear() > 1970 ) return [ ago, qsTr( "%n year",   "0", time.getFullYear() ) ]
        if( time.getMonth() > 1 )       return [ ago, qsTr( "%n month",  "0", time.getMonth()    ) ]
        if( time.getDay() > 1 )         return [ ago, qsTr( "%n day",    "0", time.getDay()      ) ]
        if( time.getHours() > 0 )       return [ ago, qsTr( "%n hour",   "0", time.getHours()    ) ]
        if( time.getMinutes() > 0 )     return [ ago, qsTr( "%n minute", "0", time.getMinutes()  ) ]
        if( time.getSeconds() > 0 )     return [ ago, qsTr( "%n second", "0", time.getSeconds()  ) ]
    }

    property alias radiusSlider: sradius
    property alias addressInput: postalCode
    property alias gpsSwitch: gpsSwitchh
    property alias searchRadius: sradius.value
    property alias address: postalCode.text
    property alias useGps: gpsSwitchh.checked
    property alias apiInput: apiKey
    property alias apiKey: apiKey.text

    onUseGpsChanged: main.gpsActive = useGps

    property string type: ""
    property variant types: []
    property variant names: []
    onTypeChanged: fuelTypeSwitcher.currentIndex = types.indexOf( type )

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contCol.height

        VerticalScrollDecorator {}

        Column {
            id: contCol
            width: page.width

            DialogHeader {
                acceptText: qsTr("Search")
                cancelText: ""
            }

            SectionHeader {
                text: qsTr("Fuel Type")
            }

            ComboBox {
                id: fuelTypeSwitcher
                width: parent.width
                    label: qsTr("Select Fuel")
                    menu: ContextMenu {
                        Repeater {
                            model: types.length
                            MenuItem {
                                text: names[index]
                                onClicked: type = types[index]
                            }
                        }
                    }
            }

            Loader {
                id: contentWrapper
                sourceComponent: content
                width: page.width-2*x
                x: Theme.horizontalPageMargin
            }

            SectionHeader {
                text: qsTr("Search Radius")
            }
            Slider {
                id: sradius
                width: parent.width
                minimumValue: 1
                maximumValue: 1
                stepSize: 1
                value: 1
                valueText: value+" "+units.distance
            }

            SectionHeader {
                text: qsTr("Location")
            }

            TextSwitch {
                id: gpsSwitchh
                text: qsTr("Use GPS")
            }
            Item {
                width: parent.width
                height: postalCode.height
                TextField {
                    id: postalCode
                    placeholderText: qsTr("Address")
                    label: placeholderText
                    anchors.left: parent.left
                    anchors.right: clear_text_btn.left
                    readOnly: useGps
                    EnterKey.enabled: text.length > 0
                    EnterKey.onClicked: focus = false
                }
                 IconButton {
                    id: clear_text_btn
                    icon.source: "image://theme/icon-m-clear?" + (pressed? Theme.highlightColor: Theme.primaryColor)
                    onClicked: postalCode.text = ""
                    anchors.right: parent.right
                    anchors.verticalCenter: postalCode.verticalCenter
                }
            }
            Item {
                width: parent.width
                height: apiKey.height
                visible: selectedPlugin==tk
                TextField {
                    id: apiKey
                    placeholderText: qsTr("API Key")
                    label: placeholderText
                    anchors.left: parent.left
                    //readOnly: apiKey
                    //EnterKey.enabled: text.length > 0
                    //EnterKey.onClicked: focus = false
                }
                 IconButton {
                    id: clear_apikey_btn
                    icon.source: "image://theme/icon-m-clear?" + (pressed? Theme.highlightColor: Theme.primaryColor)
                    onClicked: apiKey.text = ""
                    anchors.right: parent.right
                    anchors.verticalCenter: apiKey.verticalCenter
                }
            }

            ComboBox {
                id: autoUpdateSelector

                visible: false

                label: "Auto update"
                description: currentIndex==0?qsTr("Disabled"):qsTr("Every %1").arg( currentIndex==1?qsTr("%n Kilometers","",autoUpdateSlider.value):qsTr("%n Minutes","",autoUpdateSlider.value) )
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Disabled")
                    }
                    MenuItem {
                        text: qsTr("At distance")
                    }
                    MenuItem {
                        text: qsTr("At time")
                    }
                }
                onCurrentIndexChanged: {
                    autoUpdateTimer.running = currentIndex==2
                }
                Connections {
                    target: main
                    property string olat
                    property string olng

                    onLatitudeChanged: positionChanged()
                    onLongitudeChanged: positionChanged()


                    function positionChanged() {
                        if( autoUpdateSelector.currentIndex == 1 ) {
                            if( !olat || !olng ) {
                                olat = main.latitude
                                olng = main.longitude
                            } else if( getGeoDistance( olat, olng, main.latitude, main.longitude )/1000 > autoUpdateSlider.value ) {
                                olat = main.latitude
                                olng = main.longitude
                            }
                        }

                    }

                }
                Timer {
                    id: autoUpdateTimer
                    repeat: true
                    interval: autoUpdateSlider.value*60000
                    onTriggered: requestItems()
                }
            }
            Slider {
                id: autoUpdateSlider
                width: parent.width
                visible: autoUpdateSelector.currentIndex > 0
                valueText: autoUpdateSelector.currentIndex==1?qsTr("%n Kilometers","",value):qsTr("%n Minutes","",value)
                maximumValue: 100
                minimumValue: 1
                value: 1
                stepSize: 1
            }

            Item {
                width: 1
                height: Theme.horizontalPageMargin*2
            }

            ComboBox {
                //id:comboxPlugin
                width: page.width-2*x
                x: Theme.horizontalPageMargin
                label: qsTr("Plugin")
                description: selectedPlugin.description
                value: selectedPlugin.name
                currentIndex: selectedPluginNum
                menu: main.pluginSwitcher
            }
        }
    }
}

