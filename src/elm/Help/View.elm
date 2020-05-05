{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Help.View exposing (view)

import FeatherIcons
import Help.Commands
    exposing
        ( Command
        , Model
        , cliDocsUrl
        , commands
        , issuesBaseUrl
        , resourceLoaded
        , resourceLoading
        , usageDocsUrl
        )
import Html exposing (Html, a, button, details, div, input, label, li, span, strong, summary, text)
import Html.Attributes exposing (attribute, class, for, href, id, size, value)
import Html.Events
import Pages exposing (Page(..))
import SvgBuilder
import Util
import Vela exposing (Copy)


{-| view : takes help args and renders nav button for viewing contextual help for each page
-}
view : Model msg -> Html msg
view args =
    li
        [ id "contextual-help"
        , attribute "aria-label" "toggle contextual help for this page"
        ]
        [ details
            ([ class "details"
             , class "help"
             , class "-no-pad"
             , attribute "role" "button"
             ]
                ++ Util.open args.show
            )
            [ summary
                [ class "summary"
                , class "-no-pad"
                , Util.testAttribute "help-trigger"
                , Html.Attributes.tabindex 0
                , Util.onClickPreventDefault (args.toggle Nothing)
                ]
                [ SvgBuilder.terminal ]
            , help args
            ]
        ]


{-| help : takes help args and renders contextual help dropdown if focused
-}
help : Model msg -> Html msg
help args =
    div [ class "tooltip", Util.testAttribute "help-tooltip" ] <|
        [ strong [] [ text "Manage Vela resources using the CLI" ]
        ]
            ++ body args
            ++ [ footer args ]


{-| body : takes args, (page, cli commands) and renders dropdown body
-}
body : Model msg -> List (Html msg)
body args =
    let
        ( copy, cmds ) =
            ( args.copy, commands args.page )
    in
    if resourceLoading args then
        [ Util.largeLoader ]

    else if not <| resourceLoaded args then
        [ row "something went wrong!" "" Nothing ]

    else if List.length cmds == 0 then
        [ row "resources on this page not yet supported via the CLI" "" Nothing ]

    else
        List.map (contents copy) cmds


{-| footer : takes args, (page, cli commands) and renders dropdown footer
-}
footer : Model msg -> Html msg
footer args =
    if resourceLoading args then
        text ""

    else if not <| resourceLoaded args then
        div [ class "help-footer", Util.testAttribute "help-footer" ] <| notLoadedDocs args

    else
        div [ class "help-footer", Util.testAttribute "help-footer" ] <| cliDocs args


notLoadedDocs : Model msg -> List (Html msg)
notLoadedDocs _ =
    [ a [ href <| usageDocsUrl "getting-started/start_build/" ] [ text "Getting Started Docs" ]
    ]


{-| cliDocs : takes help args and renders footer docs links for commands
-}
cliDocs : Model msg -> List (Html msg)
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
            let
                forName : String
                forName =
                    command.name |> String.toLower |> String.replace " " "-"
            in
            div [ class "form-controls", class "-stack", Util.testAttribute "help-cmd-header" ]
                [ span [] [ label [ class "form-label", for forName ] [ text <| command.name ++ " " ], docsLink command ], row content forName <| Just copyMsg ]

        ( Nothing, Just issue ) ->
            div [ class "form-controls", class "-stack", Util.testAttribute "help-cmd-header" ]
                [ span [] [ text <| command.name ++ " ", upvoteFeatureLink issue ], notSupported ]

        _ ->
            text "no commands on this page"


{-| row : takes cmd content and maybe copy msg and renders cmd help row with code block and copy button
-}
row : String -> String -> Maybe (Copy msg) -> Html msg
row content forName copy =
    div
        [ class "cmd"
        , Util.testAttribute "help-row"
        ]
        [ Html.input
            [ class "cmd-text"
            , Html.Attributes.type_ "text"
            , Html.Attributes.readonly True
            , id forName
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
    div [ class "cmd", Util.testAttribute "help-row" ]
        [ Html.input
            [ class "cmd-text"
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
