{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Nav exposing (view)

import Html
    exposing
        ( Html
        , div
        , nav
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import Route exposing (Route)
import Shared



-- TYPES


type alias Props msg =
    { buttons : List (Html msg)
    , crumbs : Html msg
    }



-- VIEW


view : Shared.Model -> Route params -> Props msg -> Html msg
view shared route props =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        [ props.crumbs
        , div [ class "buttons" ] props.buttons
        ]
