{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help exposing (view)

import Dict exposing (Dict)
import FeatherIcons
import Html exposing (Html, button, code, details, div, input, li, summary, text)
import Html.Attributes exposing (attribute, class, id, type_, value)
import Html.Events exposing (onClick)
import Pages exposing (Page(..))
import Util
import Vela exposing (BuildNumber, Org, Repo)


type alias Command =
    { name : String
    , content : String
    }


type alias Commands =
    List Command


view : Page -> Bool -> msg -> Html msg
view page show toggle =
    li [ class "contextual-help" ]
        [ details [ class "details", class "-no-pad", attribute "role" "button", Util.open show, onClick toggle ]
            [ summary [ class "summary", class "-no-pad" ]
                [ FeatherIcons.terminal |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml []
                ]
            , cliHelp show <| pageToHelp page
            ]
        ]



-- details [ class "details", class "-marker-right", class "-no-pad", class "identity-name", attribute "role" "navigation" ]
--     [ summary [ class "summary" ]
--         [ text session.username
--         , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
--         ]
--     , ul [ class "identity-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
--         [ li [ class "identity-menu-item" ]
--             [ a [ Routes.href Routes.Logout, Util.testAttribute "logout-link", attribute "role" "menuitem" ] [ text "Logout" ] ]
--         ]
--     ]
-- button
--     [ Util.testAttribute "contextual-help"
--     , onClick toggle
--     , attribute "aria-label" "view cli command for this page"
--     , class "button"
--     , class "-icon"
--     , class "-white"
--     , class "contextual-help-button"
--     ]
--     [ FeatherIcons.terminal |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [] ]
-- , cliHelp show <| pageToHelp page


cliHelp : Bool -> Commands -> Html msg
cliHelp show commands =
    div [ class "contextual-help-tooltip" ] <|
        [ div [ class "-arrow" ] []
        , div [ class "-header" ] [ code [] [ text "View this page using the CLI" ] ]
        ]
            ++ List.map toHelp commands


toHelp : Command -> Html msg
toHelp command =
    div []
        [ text command.name
        , code [ class "-command" ] [ text command.content ]
        , copyButton
            [ Util.testAttribute "contextual-help"
            , attribute "aria-label" "view cli command for this page"
            , class "button"
            , class "-icon"
            , class "-white"
            ]
            command.content
        ]


copyButton : List (Html.Attribute msg) -> String -> Html msg
copyButton attributes copyText =
    button
        (attributes
            ++ [ class "copy-button"
               , attribute "data-clipboard-text" copyText
               ]
        )
        [ FeatherIcons.copy
            |> FeatherIcons.withSize 18
            |> FeatherIcons.toHtml []
        ]


builds : Org -> Repo -> Command
builds org repo =
    Command "list builds" <| "vela get builds --org " ++ org ++ " --repo " ++ repo


build : Org -> Repo -> BuildNumber -> Command
build org repo buildNumber =
    Command "get build" <| "vela get build --org " ++ org ++ " --repo " ++ repo ++ " --build " ++ buildNumber


unknown : Command
unknown =
    Command "" "unknown page"


pageToHelp : Page -> Commands
pageToHelp page =
    case page of
        Pages.RepositoryBuilds org repo _ _ ->
            [ builds org repo ]

        Pages.Build org repo buildNumber _ ->
            [ build org repo buildNumber ]

        _ ->
            [ unknown ]
