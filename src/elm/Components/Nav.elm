{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Nav exposing (view)

import Html
    exposing
        ( Html
        , button
        , nav
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        )
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import Vela



-- TYPES


type alias Props msg =
    { buttons : List (Html msg)
    , crumbs : Html msg
    }



-- VIEW


view : Shared.Model -> Route () -> Props msg -> Html msg
view shared route props =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        (props.crumbs
            :: props.buttons
        )
