{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Nav exposing (Msgs, view)

import Api.Pagination as Pagination
import Components.Crumbs
import Components.Favorites exposing (UpdateFavorites)
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , nav
        , span
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        )
import Html.Events exposing (onClick)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import Vela
    exposing
        ( Build
        , BuildNumber
        , Engine
        , Org
        , Repo
        , RepoModel
        , SecretType
        )


type alias Msgs msg =
    { fetchSourceRepos : msg
    , toggleFavorite : UpdateFavorites msg
    , refreshSettings : Org -> Repo -> msg
    , refreshHooks : Org -> Repo -> msg
    , refreshSecrets : Engine -> SecretType -> Org -> Repo -> msg
    , approveBuild : Org -> Repo -> BuildNumber -> msg
    , restartBuild : Org -> Repo -> BuildNumber -> msg
    , cancelBuild : Org -> Repo -> BuildNumber -> msg
    }


view : Shared.Model -> Route () -> List (Html msg) -> Html msg
view shared route buttons =
    nav [ class "navigation", attribute "aria-label" "Navigation" ]
        (Components.Crumbs.view route.path
            :: buttons
        )



-- BUILD


{-| cancelBuildButton : takes org repo and build number and renders button to cancel a build
-}
cancelBuildButton : Org -> Repo -> WebData Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
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
restartBuildButton : Org -> Repo -> WebData Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
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
approveBuildButton : Org -> Repo -> WebData Build -> (Org -> Repo -> BuildNumber -> msg) -> Html msg
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
