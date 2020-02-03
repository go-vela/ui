{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help exposing (view)

import FeatherIcons
import Html exposing (Html, button, code, div, input, li, text)
import Html.Attributes exposing (attribute, class, id, type_, value)
import Html.Events exposing (onClick)
import Pages exposing (Page(..))
import Util


view : Page -> Bool -> msg -> Html msg
view page show toggle =
    li [ class "cli-help" ]
        [ button
            [ Util.testAttribute "cli-help"
            , onClick toggle
            , attribute "aria-label" "view cli command for this page"
            , class "button"
            , class "-icon"
            , class "-white"
            ]
            [ FeatherIcons.terminal |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] ]
        , cliHelp show <| pageToHelp page
        ]


pageToHelp : Page -> String
pageToHelp page =
    case page of
        Pages.RepositoryBuilds org repo _ _ ->
            "vela get builds --org " ++ org ++ " --repo " ++ repo

        _ ->
            "unknown page"


cliHelp : Bool -> String -> Html msg
cliHelp show command =
    if show then
        div [ class "-tooltip" ]
            [ div [ class "-arrow" ] []
            , div [ class "-header" ] [ code [] [ text "View this page using the CLI" ] ]
            , div []
                [ code [ class "-command" ] [ text command ]
                , button
                    [ class "copy-button"
                    , Util.testAttribute "cli-help"
                    , attribute "data-clipboard-text" command
                    , attribute "aria-label" "view cli command for this page"
                    , class "button"
                    , class "-icon"
                    , class "-white"
                    ]
                    [ FeatherIcons.copy |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] ]
                ]
            ]

    else
        text ""
