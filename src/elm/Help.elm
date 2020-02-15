{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help exposing (view)

import Api.Pagination as Pagination
import FeatherIcons
import Html exposing (Html, a, button, details, div, input, li, summary, text)
import Html.Attributes exposing (attribute, class, href, id, size, value)
import Html.Events
import Pages exposing (Page(..))
import SvgBuilder
import Util
import Vela exposing (BuildNumber, Org, Repo)


type alias Command =
    { name : String
    , content : Maybe String
    , docs : Maybe String
    , issue : Maybe String
    }


type alias Commands =
    List Command


type alias Copy msg =
    String -> msg


view : Page -> Bool -> msg -> Copy msg -> Html msg
view page show noOp copyMsg =
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
                , id "contextual-help-trigger"
                ]
                [ SvgBuilder.terminal ]
            , cliHelp copyMsg <| pageToHelp page
            ]
        ]


cliHelp : Copy msg -> Commands -> Html msg
cliHelp copyMsg commands =
    div [ class "contextual-help-tooltip" ] <|
        [ div [ class "-arrow" ] []
        , div [ class "-header" ] [ text "Manage Vela resources using the CLI" ]
        ]
            ++ commandsBody copyMsg commands
            ++ [ div [ class "footer" ]
                    [ a [ href <| docsUrl "install" ] [ text "CLI Installation Docs" ]
                    , a [ href <| docsUrl "authentication" ] [ text "CLI Authentication Docs" ]
                    ]
               ]


commandsBody : Copy msg -> Commands -> List (Html msg)
commandsBody copyMsg commands =
    if List.length commands /= 0 then
        List.map (toHelp copyMsg) commands

    else
        viewCommand copyMsg "resources on this page not yet supported via the CLI" False


toHelp : Copy msg -> Command -> Html msg
toHelp copyMsg command =
    contents copyMsg command


contents : Copy msg -> Command -> Html msg
contents copyMsg command =
    case ( command.content, command.issue ) of
        ( Just content, _ ) ->
            div [ class "pls-0" ]
                [ div [ class "pls-1" ] [ text command.name, docsLink command ]
                , div [ class "pls-2" ] <| viewCommand copyMsg content True
                ]

        ( Nothing, Just issue ) ->
            div [ class "pls-0" ]
                [ div [ class "pls-1" ] [ text command.name, issueLink issue ]
                , div [ class "pls-2-3" ] viewIssue
                ]

        _ ->
            text "no commands on this page"


viewCommand : Copy msg -> String -> Bool -> List (Html msg)
viewCommand copyMsg content copy =
    [ Html.input
        [ class "-command"
        , Html.Attributes.type_ "text"
        , Html.Attributes.readonly True
        , size <| cmdSize content
        , value content
        ]
        []
    , if copy then
        copyButton
            [ Util.testAttribute "contextual-help"
            , attribute "aria-label" "view cli command for this page"
            , class "button"
            , class "-icon"
            , class "-white"
            , Html.Events.onClick <| copyMsg content
            ]
            content

      else
        text ""
    ]


viewIssue : List (Html msg)
viewIssue =
    [ Html.input
        [ class "-command"
        , Html.Attributes.type_ "text"
        , Html.Attributes.readonly True
        , size <| cmdSize "not yet supported via the CLI"
        , value "not yet supported via the CLI"
        ]
        []
    ]


cmdSize : String -> Int
cmdSize content =
    max 18 <| String.length content


copyButton : List (Html.Attribute msg) -> String -> Html msg
copyButton attributes copyText =
    if not <| String.isEmpty copyText then
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
    case command.docs of
        Just docs ->
            a [ class "command-link", href <| docsUrl docs ]
                [ text "(docs)"
                ]

        Nothing ->
            text ""


issueLink : String -> Html msg
issueLink issue =
    a [ class "command-link", href <| issuesBaseUrl ++ issue ]
        [ text "(upvote feature)"
        ]


docsUrl : String -> String
docsUrl page =
    docsBaseUrl ++ page


docsBaseUrl : String
docsBaseUrl =
    "https://go-vela.github.io/docs/cli/"


issuesBaseUrl : String
issuesBaseUrl =
    "https://github.com/go-vela/cli/issues/"


noName : String
noName =
    ""


noCmd : Maybe String
noCmd =
    Nothing


noDocs : Maybe String
noDocs =
    Nothing


noIssue : Maybe String
noIssue =
    Nothing


noCommands : Command
noCommands =
    let
        content =
            Just "commands for this page are not yet supported through the CLI"
    in
    Command noName content noDocs noIssue


listFavorites : Command
listFavorites =
    let
        name =
            "List Favorites"

        issue =
            Just "53"
    in
    Command name noCmd noDocs issue


listBuilds : Org -> Repo -> Command
listBuilds org repo =
    let
        name =
            "List Builds"

        content =
            Just <| "vela get builds " ++ repoArgs org repo

        docs =
            Just "build/get"
    in
    Command name content docs Nothing


viewBuild : Org -> Repo -> BuildNumber -> Command
viewBuild org repo buildNumber =
    let
        name =
            "View Build"

        content =
            Just <| "vela view build " ++ buildArgs org repo buildNumber

        docs =
            Just "build/view"
    in
    Command name content docs noIssue


restartBuild : Org -> Repo -> BuildNumber -> Command
restartBuild org repo buildNumber =
    let
        name =
            "Restart Build"

        content =
            Just <| "vela restart build " ++ buildArgs org repo buildNumber
    in
    Command name content noDocs Nothing


listSteps : Org -> Repo -> BuildNumber -> Command
listSteps org repo buildNumber =
    let
        name =
            "List Steps"

        content =
            Just <| "vela get steps " ++ buildArgs org repo buildNumber

        docs =
            Just "steps/get"
    in
    Command name content docs noIssue


viewStep : Org -> Repo -> BuildNumber -> Command
viewStep org repo buildNumber =
    let
        name =
            "View Step"

        content =
            Just <| "vela view step " ++ buildArgs org repo buildNumber ++ " --step 1"

        docs =
            Just "steps/get"
    in
    Command name content docs noIssue


viewRepo : Org -> Repo -> Command
viewRepo org repo =
    let
        name =
            "View Repo"

        content =
            Just <| "vela view repo " ++ repoArgs org repo

        docs =
            Just "repo/view"
    in
    Command name content docs Nothing


repairRepo : Org -> Repo -> Command
repairRepo org repo =
    let
        name =
            "Repair Repo"

        content =
            Just <| "vela repair repo " ++ repoArgs org repo

        docs =
            Just "repo/repair"
    in
    Command name content docs Nothing


chownRepo : Org -> Repo -> Command
chownRepo org repo =
    let
        name =
            "Chown Repo"

        content =
            Just <| "vela chown repo " ++ repoArgs org repo

        docs =
            Just "repo/chown"
    in
    Command name content docs Nothing


listHooks : Org -> Repo -> Command
listHooks _ _ =
    let
        name =
            "List Hooks"

        issue =
            Just "52"
    in
    Command name noCmd noDocs issue


authenticate : Command
authenticate =
    let
        name =
            "Authenticate"

        content =
            Just "vela login"

        docs =
            Just "authentication"
    in
    Command name content docs Nothing


repoArgs : Org -> Repo -> String
repoArgs org repo =
    "--org " ++ org ++ " --repo " ++ repo


buildArgs : Org -> Repo -> BuildNumber -> String
buildArgs org repo buildNumber =
    repoArgs org repo ++ " --build " ++ buildNumber


pageToHelp : Page -> Commands
pageToHelp page =
    case page of
        Pages.Overview ->
            [ listFavorites ]

        Pages.AddRepositories ->
            [ listFavorites ]

        Pages.Hooks org repo _ _ ->
            [ listHooks org repo ]

        Pages.RepositoryBuilds org repo _ _ ->
            [ listBuilds org repo ]

        Pages.Build org repo buildNumber _ ->
            [ viewBuild org repo buildNumber, restartBuild org repo buildNumber, listSteps org repo buildNumber, viewStep org repo buildNumber ]

        Pages.Settings org repo ->
            [ viewRepo org repo, repairRepo org repo, chownRepo org repo ]

        Pages.Authenticate _ ->
            []

        Pages.Login ->
            []

        Pages.Logout ->
            []

        Pages.NotFound ->
            []
