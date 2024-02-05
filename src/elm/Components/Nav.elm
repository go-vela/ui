{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Nav exposing (view)

import Components.Crumbs
import Html
    exposing
        ( Html
        , button
        , nav
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        )
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import Vela



-- TYPES


type alias Props msg =
    { buttons : List (Html msg)
    , crumbs : Html msg
    }



-- VIEW


view : Shared.Model -> Route () -> Props msg -> Html msg
view shared route props =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        (props.crumbs
            :: props.buttons
        )



-- BUILD


{-| cancelBuildButton : takes org repo and build number and renders button to cancel a build
-}
cancelBuildButton : Vela.Org -> Vela.Repo -> WebData Vela.Build -> (Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg) -> Html msg
cancelBuildButton org repo build cancelBuild =
    case build of
        RemoteData.Success b ->
            let
                cancelButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| cancelBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "cancel-build"
                        ]
                        [ text "Cancel Build"
                        ]
            in
            case b.status of
                Vela.Running ->
                    cancelButton

                Vela.Pending ->
                    cancelButton

                Vela.PendingApproval ->
                    cancelButton

                _ ->
                    text ""

        _ ->
            text ""


{-| restartBuildButton : takes org repo and build number and renders button to restart a build
-}
restartBuildButton : Vela.Org -> Vela.Repo -> WebData Vela.Build -> (Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg) -> Html msg
restartBuildButton org repo build restartBuild =
    case build of
        RemoteData.Success b ->
            let
                restartButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| restartBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "restart-build"
                        ]
                        [ text "Restart Build"
                        ]
            in
            case b.status of
                Vela.PendingApproval ->
                    text ""

                _ ->
                    restartButton

        _ ->
            text ""


{-| approveBuildButton: takes org repo and build number and renders button to approve a build run
-}
approveBuildButton : Vela.Org -> Vela.Repo -> WebData Vela.Build -> (Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg) -> Html msg
approveBuildButton org repo build approveBuild =
    case build of
        RemoteData.Success b ->
            let
                approveButton =
                    button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| approveBuild org repo <| String.fromInt b.number
                        , Util.testAttribute "approve-build"
                        ]
                        [ text "Approve Build"
                        ]
            in
            case b.status of
                Vela.PendingApproval ->
                    approveButton

                _ ->
                    text ""

        _ ->
            text ""
