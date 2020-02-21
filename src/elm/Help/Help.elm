{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help.Help exposing (Arg, Args, view)

import FeatherIcons
import Help.Commands exposing (Command, commands)
import Html exposing (Html, a, button, details, div, input, li, summary, text)
import Html.Attributes exposing (attribute, class, href, id, size, value)
import Html.Events
import Pages exposing (Page(..))
import SvgBuilder
import Util
import Vela exposing (Copy)


{-| Args : wrapper for help args, meant to slim down the input required to render contextual help for each page
-}
type alias Args msg =
    { user : Arg
    , sourceRepos : Arg
    , builds : Arg
    , build : Arg
    , repo : Arg
    , hooks : Arg
    , show : Bool
    , copy : Copy msg
    , noOp : msg
    , page : Page
    }


{-| Arg : type alias for extracting remotedata information
-}
type alias Arg =
    { loading : Bool
    , success : Bool
    }


{-| view : takes help args and renders nav button for viewing contextual help for each page
-}
view : Args msg -> Html msg
view args =
    li
        [ id "contextual-help"
        , attribute "aria-label" "toggle contextual help for this page"
        , Html.Attributes.tabindex 0
        ]
        [ details
            [ class "details"
            , class "help"
            , class "-no-pad"
            , attribute "role" "button"
            , Util.open args.show
            , Html.Attributes.tabindex -1
            , Util.onClickPreventDefault args.noOp
            ]
            [ summary
                [ class "summary"
                , class "-no-pad"
                , id "contextual-help-trigger"
                , Util.testAttribute "help-trigger"
                ]
                [ SvgBuilder.terminal ]
            , help args
            ]
        ]


{-| help : takes help args and renders contextual help dropdown if focused
-}
help : Args msg -> Html msg
help args =
    div [ class "toolip", Util.testAttribute "help-tooltip" ] <|
        [ div [ class "arrow" ] []
        , div [] [ text "Manage Vela resources using the CLI" ]
        ]
            ++ body args
            ++ [ footer args ]


{-| body : takes args, (page, cli commands) and renders dropdown body
-}
body : Args msg -> List (Html msg)
body args =
    let
        ( copy, cmds ) =
            ( args.copy, commands args.page )
    in
    if resourceLoading args then
        [ Util.largeLoader ]

    else if not <| resourceLoaded args then
        [ row "something went wrong!" Nothing ]

    else if List.length cmds == 0 then
        [ row "resources on this page not yet supported via the CLI" Nothing ]

    else
        List.map (contents copy) cmds


{-| footer : takes args, (page, cli commands) and renders dropdown footer
-}
footer : Args msg -> Html msg
footer args =
    if resourceLoading args then
        text ""

    else if not <| resourceLoaded args then
        div [ class "help-footer", Util.testAttribute "help-footer" ] <| notLoadedDocs args

    else
        div [ class "help-footer", Util.testAttribute "help-footer" ] <| cliDocs args


notLoadedDocs : Args msg -> List (Html msg)
notLoadedDocs _ =
    [ a [ href <| usageDocsUrl "getting-started/start_build/" ] [ text "Getting Started Docs" ]
    ]


{-| cliDocs : takes help args and renders footer docs links for commands
-}
cliDocs : Args msg -> List (Html msg)
cliDocs _ =
    [ a [ href <| cliDocsUrl "install" ] [ text "CLI Installation Docs" ]
    , a [ href <| cliDocsUrl "authentication" ] [ text "CLI Authentication Docs" ]
    ]


{-| contents : takes help args and renders body content for command
-}
contents : Copy msg -> Command -> Html msg
contents copyMsg command =
    case ( command.content, command.issue ) of
        ( Just content, _ ) ->
            div [ class "-cmd-pad" ]
                [ div [ class "-center-row", Util.testAttribute "help-cmd-header" ]
                    [ text command.name, docsLink command ]
                , row content <| Just copyMsg
                ]

        ( Nothing, Just issue ) ->
            div [ class "-cmd-pad" ]
                [ div [ class "-center-row", Util.testAttribute "help-cmd-header" ]
                    [ text command.name, upvoteFeatureLink issue ]
                , notSupported
                ]

        _ ->
            text "no commands on this page"


{-| row : takes cmd content and maybe copy msg and renders cmd help row with code block and copy button
-}
row : String -> Maybe (Copy msg) -> Html msg
row content copy =
    div
        [ class "-center-row"
        , class "-m-top"
        , Util.testAttribute "help-row"
        ]
        [ Html.input
            [ class "cmd"
            , Html.Attributes.type_ "text"
            , Html.Attributes.readonly True
            , size <| cmdSize content
            , value content
            ]
            []
        , case copy of
            Just copyMsg ->
                copyButton
                    [ Util.testAttribute "help-copy"
                    , attribute "aria-label" <| "copy " ++ content ++ " to clipboard"
                    , class "button"
                    , class "-icon"
                    , class "-white"
                    , Html.Events.onClick <| copyMsg content
                    ]
                    content

            Nothing ->
                text ""
        ]


{-| notSupported : renders help row for commands not yet supported by the cli
-}
notSupported : Html msg
notSupported =
    div [ class "-m-top", Util.testAttribute "help-row" ]
        [ Html.input
            [ class "cmd"
            , Html.Attributes.type_ "text"
            , Html.Attributes.readonly True
            , size <| cmdSize "not yet supported via the CLI"
            , value "not yet supported via the CLI"
            ]
            []
        ]


{-| docsLink : takes command and returns docs link if appropriate
-}
docsLink : Command -> Html msg
docsLink command =
    case command.docs of
        Just docs ->
            a
                [ class "cmd-link"
                , href <| cliDocsUrl docs
                , attribute "aria-label" <| "go to cli docs page for " ++ docs
                ]
                [ text "(docs)"
                ]

        Nothing ->
            text ""


{-| upvoteFeatureLink : takes command and returns issue upvote link if appropriate
-}
upvoteFeatureLink : String -> Html msg
upvoteFeatureLink issue =
    a [ class "cmd-link", href <| issuesBaseUrl ++ issue ]
        [ text "(upvote feature)"
        ]


{-| copyButton : takes command content and returns copy pasteable button controlled by Clipboard.js
-}
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


{-| cmdSize : takes command content and returns appropriate size for readonly input
-}
cmdSize : String -> Int
cmdSize content =
    max 18 <| String.length content


{-| cliDocsUrl : takes page and returns cli docs url
-}
cliDocsUrl : String -> String
cliDocsUrl page =
    cliDocsBase ++ page


{-| usageDocsUrl : takes page and returns usage docs url
-}
usageDocsUrl : String -> String
usageDocsUrl page =
    usageDocsBase ++ page


docsBase : String
docsBase =
    "https://go-vela.github.io/docs/"


{-| cliDocsBase : returns base url for cli docs
-}
cliDocsBase : String
cliDocsBase =
    docsBase ++ "cli/"


{-| usageDocsBase : returns base url for usage docs
-}
usageDocsBase : String
usageDocsBase =
    docsBase ++ "usage/"


{-| usageDocsBase : returns base url for cli issues
-}
issuesBaseUrl : String
issuesBaseUrl =
    "https://github.com/go-vela/cli/issues/"


{-| resourceLoaded : takes help args and returns if the resource has been successfully loaded
-}
resourceLoaded : Args msg -> Bool
resourceLoaded args =
    case args.page of
        Pages.Overview ->
            args.user.success

        Pages.AddRepositories ->
            args.sourceRepos.success

        Pages.RepositoryBuilds _ _ _ _ _ ->
            args.builds.success

        Pages.Build _ _ _ _ ->
            args.build.success

        Pages.RepoSettings _ _ ->
            args.repo.success

        Pages.Hooks _ _ _ _ ->
            args.hooks.success

        Pages.Settings ->
            True

        Pages.Login ->
            True

        Pages.Logout ->
            True

        Pages.Authenticate _ ->
            True

        Pages.NotFound ->
            False


{-| resourceLoading : takes help args and returns if the resource is loading
-}
resourceLoading : Args msg -> Bool
resourceLoading args =
    case args.page of
        Pages.Overview ->
            args.user.loading

        Pages.AddRepositories ->
            args.sourceRepos.loading

        Pages.RepositoryBuilds _ _ _ _ _ ->
            args.builds.loading

        Pages.Build _ _ _ _ ->
            args.build.loading

        Pages.RepoSettings _ _ ->
            args.repo.loading

        Pages.Hooks _ _ _ _ ->
            args.hooks.loading

        Pages.Settings ->
            False

        Pages.Login ->
            False

        Pages.Logout ->
            True

        Pages.Authenticate _ ->
            True

        Pages.NotFound ->
            False
