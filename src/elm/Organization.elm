{--
SPDX-License-Identifier: Apache-2.0
--}


module Organization exposing (..)

import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , em
        , h1
        , li
        , ol
        , p
        , text
        )
import Html.Attributes exposing (class, href)
import Pages.Build.Model exposing (Msgs)
import Pages.Build.View exposing (viewPreview)
import RemoteData exposing (RemoteData(..))
import Routes
import Time exposing (Posix, Zone)
import Utils.Errors as Errors exposing (viewResourceError)
import Utils.Helpers as Util exposing (largeLoader)
import Vela exposing (BuildsModel, Event, Org, OrgReposModel, Repository)


viewBuilds : BuildsModel -> Msgs msg -> List Int -> Posix -> Zone -> Org -> Maybe Event -> Html msg
viewBuilds buildsModel msgs openMenus now zone org maybeEvent =
    let
        none : Html msg
        none =
            case maybeEvent of
                Nothing ->
                    div []
                        [ h1 [] [ text "No builds were found for this Organization!" ]
                        , p [] [ text "Builds will show up here once you have:" ]
                        , ol [ class "list" ]
                            [ li []
                                [ text "A "
                                , code [] [ text ".vela.yml" ]
                                , text " file that describes your build pipeline in the root of your repository."
                                , br [] []
                                , a [ href "https://go-vela.github.io/docs/usage/" ] [ text "Review the documentation" ]
                                , text " for help or "
                                , a [ href "https://go-vela.github.io/docs/usage/examples/" ] [ text "check some of the pipeline examples" ]
                                , text "."
                                ]
                            , li []
                                [ text "Trigger one of the "
                                , text " by performing the respective action via "
                                , em [] [ text "Git" ]
                                , text "."
                                ]
                            ]
                        , p [] [ text "Happy building!" ]
                        ]

                Just event ->
                    div []
                        [ h1 [] [ text <| "No builds for \"" ++ event ++ "\" event found." ] ]
    in
    case buildsModel.builds of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <| List.map (viewPreview msgs openMenus False now zone org "" buildsModel.showTimestamp) builds

        RemoteData.Loading ->
            largeLoader

        RemoteData.NotAsked ->
            largeLoader

        RemoteData.Failure _ ->
            viewResourceError { resourceLabel = "builds for this org", testLabel = "builds" }


{-| viewOrgRepos : renders repositories for the provided org
-}
viewOrgRepos : Org -> OrgReposModel -> Html msg
viewOrgRepos org repos =
    case repos.orgRepos of
        Success r ->
            if List.length r == 0 then
                div []
                    [ h1 [] [ text "No Repositories are enabled for this Organization!" ]
                    , p [] [ text "Enable repositories" ]
                    , a
                        [ class "button"
                        , class "-outline"
                        , Util.testAttribute "source-repos"
                        , Routes.href <| Routes.SourceRepositories
                        ]
                        [ text "Source Repositories" ]
                    ]

            else
                div [] (List.map (viewOrgRepo org) r)

        Loading ->
            largeLoader

        NotAsked ->
            largeLoader

        Failure _ ->
            viewResourceError { resourceLabel = "repos for this org", testLabel = "repos" }


{-| viewOrgRepo : renders row of repos with action buttons
-}
viewOrgRepo : Org -> Repository -> Html msg
viewOrgRepo org repo =
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "buttons" ]
            [ a
                [ class "button"
                , class "-outline"
                , Routes.href <| Routes.RepoSettings org repo.name
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks org repo.name Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Routes.href <| Routes.RepoSecrets "native" org repo.name Nothing Nothing
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds org repo.name Nothing Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]
