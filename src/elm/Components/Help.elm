{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Help exposing (Command, Props, cmdSize, view)

import Components.Svgs as SvgBuilder
import FeatherIcons
import Html exposing (Html, a, button, details, div, input, label, span, strong, summary, text)
import Html.Attributes exposing (attribute, class, for, href, id, readonly, size, tabindex, type_, value)
import Html.Events exposing (onClick)
import Shared
import Utils.Helpers as Util



-- TYPES


{-| Props : alias for an object representing properties for the contextual help component.
-}
type alias Props msg =
    { show : Bool
    , showHide : Maybe Bool -> msg
    , commands : List Command
    , showCopyAlert : String -> msg
    }


{-| Command : alias for an object representing the attributes of a command.
-}
type alias Command =
    { name : String
    , content : String
    , docs : Maybe String
    }



-- VIEW


{-| view : renders contextual help component when tooltip is selected.
-}
view : Shared.Model -> Props msg -> Html msg
view shared props =
    details
        (class "details"
            :: class "help"
            :: class "-no-pad"
            :: Util.open props.show
        )
        [ summary
            [ class "summary"
            , class "-no-pad"
            , Util.testAttribute "help-trigger"
            , tabindex 0
            , Util.onClickPreventDefault (props.showHide Nothing)
            ]
            [ SvgBuilder.terminal ]
        , div [ class "tooltip", Util.testAttribute "help-tooltip" ] <|
            strong [] [ text "Manage Vela resources using the CLI" ]
                :: List.map (viewCommand shared props) props.commands
                ++ [ div [ class "help-footer", Util.testAttribute "help-footer" ]
                        [ a [ href <| shared.velaDocsURL ++ "/reference/cli/install" ] [ text "CLI Installation Docs" ]
                        , a [ href <| shared.velaDocsURL ++ "/reference/cli/authentication" ] [ text "CLI Authentication Docs" ]
                        ]
                   ]
        ]


{-| viewCommand : renders contextual cli command and cli doc link.
-}
viewCommand : Shared.Model -> Props msg -> Command -> Html msg
viewCommand shared props command =
    div [ class "form-controls", class "-stack", Util.testAttribute "help-cmd-header" ]
        [ span []
            [ label [ class "form-label", for <| "" ] [ text <| command.name ++ " " ]
            , case command.docs of
                Just docs ->
                    a
                        [ class "cmd-link"
                        , href <| shared.velaDocsURL ++ "/reference/cli/" ++ docs
                        , attribute "aria-label" <| "go to cli docs page for " ++ docs
                        ]
                        [ text "(docs)"
                        ]

                Nothing ->
                    text ""
            ]
        , div
            [ class "cmd"
            , Util.testAttribute "help-row"
            ]
            [ input
                [ class "cmd-text"
                , type_ "text"
                , readonly True
                , id command.name
                , size <| cmdSize command.content
                , value command.content
                ]
                []
            , if not <| String.isEmpty command.content then
                div [ class "vert-icon-container" ]
                    [ button
                        [ Util.testAttribute "help-copy"
                        , attribute "aria-label" <| "copy " ++ command.content ++ " to clipboard"
                        , class "button"
                        , class "-icon"
                        , onClick <| props.showCopyAlert command.content
                        , class "copy-button"
                        , attribute "data-clipboard-text" command.content
                        ]
                        [ FeatherIcons.copy
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml []
                        ]
                    ]

              else
                text ""
            ]
        ]


{-| cmdSize : takes command content and returns appropriate size for readonly input; max value of 18 is arbitrary.
-}
cmdSize : String -> Int
cmdSize content =
    max 18 <| String.length content
