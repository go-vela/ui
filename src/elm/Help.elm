{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help exposing (view)

import Api.Pagination as Pagination
import FeatherIcons
import Html exposing (Html, a, button, details, div, input, li, summary, text)
import Html.Attributes exposing (attribute, class, href, id, size, value)
import Pages exposing (Page(..))
import Svg.Attributes
import Util
import Vela exposing (BuildNumber, Org, Repo)


type alias Command =
    { name : String
    , content : String
    , pagination : Maybe String
    , docs : String
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
    div [ class "contextual-help-tooltip" ] <|
        [ div [ class "-arrow" ] []
        , div [ class "-header" ] [ text "Manage Vela resources using the CLI" ]
        ]
            -- , div [ class "commands-wrapper" ]
            --     [ div [ class "commands" ]
            --         [ names commands
            --         , contents commands
            --         ]
            --     ]
            ++ commandsBody commands
            ++ [ div [ class "footer" ]
                    [ a [ href "https://go-vela.github.io/docs/cli/install/" ] [ text "CLI Installation Docs" ]
                    , a [ href "https://go-vela.github.io/docs/cli/authentication/" ] [ text "CLI Authentication Docs" ]
                    ]
               ]


commandsBody : Commands -> List (Html msg)
commandsBody commands =
    if List.length commands /= 0 then
        List.map toHelp commands

    else
        [ div [] [ text "" ] ]


toHelp : Command -> Html msg
toHelp command =
    div [ class "pls-0" ]
        [ div [ class "pls-1" ] [ text command.name, docsLink command ]
        , div [ class "pls-2" ]
            [ Html.input
                [ class "-command"
                , size <| cmdSize command
                , value command.content
                ]
                []
            , copyButton
                [ Util.testAttribute "contextual-help"
                , attribute "aria-label" "view cli command for this page"
                , class "button"
                , class "-icon"
                , class "-white"
                ]
                command.content
            ]
        ]


names : Commands -> Html msg
names commands =
    div [ class "command-names" ] <| List.map (\command -> div [ class "min-height-pls", class "justify-right" ] [ Html.span [ class "vertical-pls" ] [ text <| command.name ++ ":" ] ]) commands


contents : Commands -> Html msg
contents commands =
    div [ class "command-contents" ] <|
        List.map
            (\command ->
                Html.div [ class "min-height-pls" ]
                    [ Html.input
                        [ class "-command"
                        , size <| cmdSize command
                        , value command.content
                        ]
                        []
                    , copyButton
                        [ Util.testAttribute "contextual-help"
                        , attribute "aria-label" "view cli command for this page"
                        , class "button"
                        , class "-icon"
                        , class "-white"
                        ]
                        command.content
                    , docsLink command
                    ]
            )
            commands


cmdSize : Command -> Int
cmdSize command =
    max 18 <|
        String.length command.content


copyButton : List (Html.Attribute msg) -> String -> Html msg
copyButton attributes copyText =
    if copyText /= noCmd then
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

    else
        text ""


docsLink : Command -> Html msg
docsLink command =
    if command.docs /= "" then
        a [ class "docs-button", href <| docsBaseUrl ++ command.docs ]
            [ text "(docs)"
            ]

    else
        text ""


authenticate : Command
authenticate =
    let
        name =
            "Authenticate"

        content =
            "vela login"

        docs =
            "/cli/authentication"
    in
    Command name content Nothing docs


docsBaseUrl : String
docsBaseUrl =
    "https://go-vela.github.io/docs"


noDocs : String
noDocs =
    ""


noName : String
noName =
    ""


listFavorites : Command
listFavorites =
    let
        name =
            "List Favorites"

        content =
            noCmd

        docs =
            noDocs
    in
    Command name content Nothing docs


listBuilds : Org -> Repo -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Command
listBuilds org repo pageNum perPage =
    let
        name =
            "List Builds"

        content =
            "vela get builds " ++ repoArgs org repo

        pag =
            pagination pageNum perPage

        docs =
            "/cli/build/get"
    in
    Command name content (Just pag) docs


pagination : Maybe Pagination.Page -> Maybe Pagination.PerPage -> String
pagination pageNum perPage =
    case ( pageNum, perPage ) of
        ( Just pN, Just pP ) ->
            "--page " ++ String.fromInt pN ++ " --per-page " ++ String.fromInt pP

        ( Just pN, Nothing ) ->
            "--page " ++ String.fromInt pN

        ( Nothing, Just pP ) ->
            "--perpage " ++ String.fromInt pP

        ( Nothing, Nothing ) ->
            ""


viewBuild : Org -> Repo -> BuildNumber -> Command
viewBuild org repo buildNumber =
    let
        name =
            "View Build"

        content =
            "vela view build " ++ buildArgs org repo buildNumber

        docs =
            "/cli/build/view"
    in
    Command name content Nothing docs


restartBuild : Org -> Repo -> BuildNumber -> Command
restartBuild org repo buildNumber =
    let
        name =
            "Restart Build"

        content =
            "vela restart build " ++ buildArgs org repo buildNumber

        docs =
            noDocs
    in
    Command name content Nothing docs


listHooks : Org -> Repo -> Command
listHooks _ _ =
    let
        name =
            "List Hooks"

        content =
            noCmd

        docs =
            noDocs
    in
    Command name content Nothing docs


repoArgs : Org -> Repo -> String
repoArgs org repo =
    "--org " ++ org ++ " --repo " ++ repo


buildArgs : Org -> Repo -> BuildNumber -> String
buildArgs org repo buildNumber =
    repoArgs org repo ++ " --build " ++ buildNumber


unknown : Command
unknown =
    Command noName noCmd Nothing noDocs


pageToHelp : Page -> Commands
pageToHelp page =
    case page of
        Pages.Overview ->
            []

        Pages.AddRepositories ->
            []

        Pages.Hooks org repo _ _ ->
            [ listHooks org repo ]

        Pages.RepositoryBuilds org repo pageNum perPage ->
            [ listBuilds org repo pageNum perPage ]

        Pages.Build org repo buildNumber _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber ]

        Pages.Settings _ _ ->
            []

        Pages.Authenticate _ ->
            []

        Pages.Login ->
            []

        Pages.Logout ->
            []

        Pages.NotFound ->
            []


noCmd : String
noCmd =
    "coming soon!"
