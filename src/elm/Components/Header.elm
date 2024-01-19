{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Header exposing (view)

import Auth.Session exposing (Session(..))
import Components.Help
import Components.Svgs exposing (velaLogo)
import FeatherIcons
import Html exposing (Html, a, button, details, div, header, li, nav, summary, text, ul)
import Html.Attributes exposing (attribute, class, classList, href, id)
import Html.Events exposing (onClick)
import Route.Path
import Utils.HelpCommands
import Utils.Helpers as Util
import Vela exposing (Theme(..))


view : { session : Session, feedbackLink : String, docsLink : String, theme : Theme, setTheme : Theme -> msg, help : Utils.HelpCommands.Model msg, showId : Bool, showHideIdentity : Maybe Bool -> msg } -> Html msg
view { session, feedbackLink, docsLink, theme, setTheme, help, showId, showHideIdentity } =
    let
        identityBaseClassList : Html.Attribute msg
        identityBaseClassList =
            classList
                [ ( "details", True )
                , ( "-marker-right", True )
                , ( "-no-pad", True )
                , ( "identity-name", True )
                ]

        identityAttributeList : List (Html.Attribute msg)
        identityAttributeList =
            Util.open showId
    in
    header []
        [ div [ class "identity", id "identity", Util.testAttribute "identity" ]
            [ a
                [ Route.Path.href Route.Path.Home_
                , class "identity-logo-link"
                , attribute "aria-label" "Home"
                ]
                [ velaLogo 24 ]
            , case session of
                Authenticated auth ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (showHideIdentity Nothing), Util.testAttribute "identity-summary" ]
                            [ text auth.userName
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , ul [ class "identity-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                            [ li [ class "identity-menu-item" ]
                                [ a
                                    [ Util.testAttribute "settings-link"
                                    , Route.Path.href Route.Path.AccountSettings_
                                    , attribute "role" "menuitem"
                                    ]
                                    [ text "Settings" ]
                                ]
                            , li [ class "identity-menu-item" ]
                                [ a
                                    [ Util.testAttribute "logout-link"
                                    , Route.Path.href Route.Path.AccountLogout_
                                    , attribute "role" "menuitem"
                                    ]
                                    [ text "Logout" ]
                                ]
                            ]
                        ]

                Unauthenticated ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (showHideIdentity Nothing), Util.testAttribute "identity-summary" ] [ text "Vela" ] ]
            ]
        , nav [ class "help-links" ]
            [ ul []
                [ li [] [ viewThemeToggle theme setTheme ]
                , li [] [ a [ href feedbackLink, attribute "aria-label" "go to feedback" ] [ text "feedback" ] ]
                , li [] [ a [ href docsLink, attribute "aria-label" "go to docs" ] [ text "docs" ] ]
                , Components.Help.help help
                ]
            ]
        ]


viewThemeToggle : Theme -> (Theme -> msg) -> Html msg
viewThemeToggle theme setTheme =
    let
        ( newTheme, themeAria ) =
            case theme of
                Dark ->
                    ( Light, "enable light mode" )

                Light ->
                    ( Dark, "enable dark mode" )
    in
    button [ class "button", class "-link", attribute "aria-label" themeAria, onClick (setTheme newTheme) ] [ text "switch theme" ]
