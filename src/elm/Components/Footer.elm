{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Footer exposing (view)

import Components.Alerts as Alerts exposing (Alert)
import Html exposing (Html, div)
import Html.Attributes exposing (class)
import Toasty as Alerting exposing (Stack)
import Util.Helpers as Util


view :
    { toasties : Stack Alert
    , copyAlertMsg : String -> msg
    , alertsUpdateMsg : Alerting.Msg Alert -> msg
    }
    -> Html msg
view options =
    Html.footer []
        [ div [ Util.testAttribute "alerts", class "alerts" ]
            [ Alerting.view Alerts.successConfig
                (Alerts.view options.copyAlertMsg)
                options.alertsUpdateMsg
                options.toasties
            ]
        ]
