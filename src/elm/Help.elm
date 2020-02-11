{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help exposing (view)

import FeatherIcons
import Html exposing (Html, button, code, details, div, li, summary, text)
import Html.Attributes exposing (attribute, class, id)
import Html.Events exposing (onClick)
import Pages exposing (Page(..))
import Svg.Attributes
import Util
import Vela exposing (BuildNumber, Org, Repo)


type alias Command =
    { name : String
    , content : String
    }


type alias Commands =
    List Command


view : Page -> Bool -> (Maybe Bool -> msg) -> msg -> Html msg
view page show showHideHelp noOp =
    li
        [ id "contextual-help-parent"
        ]
        [ details
            [ class "details"
            , class "contextual-help"
            , class "-no-pad"
            , id "contextual-help-details"
            , attribute "role" "button"
            , Util.open show
            , Util.onClickPreventDefault noOp
            ]
            [ summary
                [ class "summary"
                , class "-no-pad"
                , id "contextual-help-summary"
                ]
                [ FeatherIcons.terminal
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml [ Svg.Attributes.id "contextual-help-icon" ]
                ]
            , cliHelp (pageToHelp page) noOp
            ]
        ]


cliHelp : Commands -> msg -> Html msg
cliHelp commands noOp =
    div
        [ class "contextual-help-tooltip"
        , id "contextual-help-tooltip"
        ]
    <|
        [ div [ class "-arrow", id "contextual-help-arrow" ] []
        , div [ class "-header", id "contextual-help-header" ] [ code [] [ text "View this page using the CLI" ] ]
        ]
            ++ List.map (toHelp noOp) commands


toHelp : msg -> Command -> Html msg
toHelp noOp command =
    div [ id "contextual-help-content" ]
        [ text command.name
        , code [ class "-command", id "contextual-help-code" ] [ text command.content ]
        , copyButton
            [ Util.testAttribute "contextual-help"
            , attribute "aria-label" "view cli command for this page"
            , class "button"
            , class "-icon"
            , class "-white"
            , id "contextual-help-copy-button"
            ]
            command.content
            noOp
        ]


copyButton : List (Html.Attribute msg) -> String -> msg -> Html msg
copyButton attributes copyText noOp =
    button
        (attributes
            ++ [ class "copy-button"
               , attribute "data-clipboard-text" copyText

               --    , Util.onClickStopPropogation <| noOp
               ]
        )
        [ FeatherIcons.copy
            |> FeatherIcons.withSize 18
            |> FeatherIcons.toHtml [ Svg.Attributes.id "contextual-help-copy-icon" ]
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
