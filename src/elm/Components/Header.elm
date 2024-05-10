{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Header exposing (view)

import Auth.Session exposing (Session(..))
import Components.Help
import Components.Svgs exposing (velaLogo)
import Dict
import FeatherIcons
import Html exposing (Html, a, button, details, div, header, li, nav, summary, text, ul)
import Html.Attributes exposing (attribute, class, classList, href, id)
import Html.Events exposing (onClick)
import Route
import Route.Path
import Shared
import Utils.Helpers as Util
import Utils.Theme as Theme



-- TYPES


{-| Props : alias for an object representing properties for the header component.
-}
type alias Props msg =
    { from : String
    , theme : Theme.Theme
    , setTheme : Theme.Theme -> msg
    , helpProps : Components.Help.Props msg
    , showId : Bool
    , showHideIdentity : Maybe Bool -> msg
    }



-- VIEW


{-| view : renders the header component.
-}
view : Shared.Model -> Props msg -> Html msg
view shared props =
    let
        identityBaseClassList =
            classList
                [ ( "details", True )
                , ( "-marker-right", True )
                , ( "-no-pad", True )
                , ( "identity-name", True )
                ]

        identityAttributeList =
            Util.open props.showId
    in
    header []
        [ div [ class "identity", id "identity", Util.testAttribute "identity" ]
            [ a
                [ Route.Path.href Route.Path.Home_
                , class "identity-logo-link"
                , attribute "aria-label" "Home"
                ]
                [ velaLogo 24 ]
            , case shared.session of
                Authenticated auth ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (props.showHideIdentity Nothing), Util.testAttribute "identity-summary" ]
                            [ text auth.userName
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , ul [ class "identity-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                            [ li [ class "identity-menu-item" ]
                                [ a
                                    [ Util.testAttribute "settings-link"
                                    , Route.Path.href Route.Path.Account_Settings
                                    , attribute "role" "menuitem"
                                    , onClick (props.showHideIdentity (Just False))
                                    ]
                                    [ text "Settings" ]
                                ]
                            , li [ class "identity-menu-item" ]
                                [ a
                                    [ Util.testAttribute "logout-link"
                                    , Route.href
                                        { path = Route.Path.Account_Logout
                                        , query =
                                            Dict.fromList
                                                [ ( "from", props.from ) ]
                                        , hash = Nothing
                                        }
                                    , attribute "role" "menuitem"
                                    , onClick (props.showHideIdentity (Just False))
                                    ]
                                    [ text "Logout" ]
                                ]
                            ]
                        ]

                Unauthenticated ->
                    details (identityBaseClassList :: identityAttributeList)
                        [ summary [ class "summary", Util.onClickPreventDefault (props.showHideIdentity Nothing), Util.testAttribute "identity-summary" ] [ text "Vela" ] ]
            ]
        , nav [ class "help-links" ]
            [ ul []
                [ li []
                    [ viewThemeToggle props.theme props.setTheme
                    ]
                , li []
                    [ a
                        [ href shared.velaFeedbackURL, attribute "aria-label" "go to feedback" ]
                        [ text "feedback" ]
                    ]
                , li []
                    [ a
                        [ href shared.velaDocsURL, attribute "aria-label" "go to docs" ]
                        [ text "docs" ]
                    ]
                , li
                    [ id "contextual-help"
                    , attribute "aria-label" "toggle contextual help for this page"
                    ]
                    [ Components.Help.view shared props.helpProps
                    ]
                ]
            ]
        ]


{-| viewThemeToggle : renders a theme toggle button.
-}
viewThemeToggle : Theme.Theme -> (Theme.Theme -> msg) -> Html msg
viewThemeToggle theme setTheme =
    let
        ( newTheme, themeAria ) =
            case theme of
                Theme.Dark ->
                    ( Theme.Light, "enable light mode" )

                Theme.Light ->
                    ( Theme.Dark, "enable dark mode" )
    in
    button
        [ class "button"
        , class "-link"
        , attribute "aria-label" themeAria
        , onClick (setTheme newTheme)
        ]
        [ text "switch theme" ]
