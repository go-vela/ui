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


{-| Props : alias for an object representing properties for the navigation component.
-}
type alias Props msg =
    { buttons : List (Html msg)
    , crumbs : Html msg
    }



-- VIEW


{-| view : renders the navigation component.
-}
view : Shared.Model -> Route params -> Props msg -> Html msg
view shared route props =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        [ props.crumbs
        , div [ class "buttons" ] props.buttons
        ]
