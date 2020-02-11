{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help exposing (view)

import FeatherIcons
import Html exposing (Html, button, code, details, div, li, summary, text)
import Html.Attributes exposing (attribute, class, id)
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


view : Page -> Bool -> msg -> Html msg
view page show noOp =
    li
        [ id "contextual-help"
        ]
        [ details
            [ class "details"
            , class "contextual-help"
            , class "-no-pad"
            , attribute "role" "button"
            , Util.open show
            , Util.onClickPreventDefault noOp
            ]
            [ summary
                [ class "summary"
                , class "-no-pad"
                ]
                [ FeatherIcons.terminal
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml [ Svg.Attributes.id "contextual-help-icon" ]
                ]
            , cliHelp <| pageToHelp page
            ]
        ]


cliHelp : Commands -> Html msg
cliHelp commands =
    div
        [ class "contextual-help-tooltip"
        ]
    <|
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
    let
        label =
            "list builds"

        command =
            "vela get builds " ++ repoArgs org repo
    in
    Command label command


build : Org -> Repo -> BuildNumber -> Command
build org repo buildNumber =
    let
        label =
            "get build"

        command =
            "vela get build " ++ buildArgs org repo buildNumber
    in
    Command label command


repoArgs : Org -> Repo -> String
repoArgs org repo =
    "--org " ++ org ++ " --repo " ++ repo


buildArgs : Org -> Repo -> BuildNumber -> String
buildArgs org repo buildNumber =
    repoArgs org repo ++ " --build " ++ buildNumber


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
