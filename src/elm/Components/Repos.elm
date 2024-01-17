{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Repos exposing (view)

import Html
    exposing
        ( Html
        , a
        , div
        , h1
        , p
        , text
        )
import Html.Attributes exposing (class)
import RemoteData exposing (RemoteData(..), WebData)
import Routes
import Shared
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela


type alias Props =
    { repos : WebData (List Vela.Repository)
    }


{-| view : renders repositories for the provided org
-}
view : Shared.Model -> Props -> Html msg
view shared props =
    case props.repos of
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
                div [] (List.map viewRepo r)

        Loading ->
            Util.largeLoader

        NotAsked ->
            Util.largeLoader

        Failure _ ->
            Errors.viewResourceError { resourceLabel = "repos for this org", testLabel = "repos" }


{-| viewRepo : renders row of repos with action buttons
-}
viewRepo : Vela.Repository -> Html msg
viewRepo repo =
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "buttons" ]
            [ a
                [ class "button"
                , class "-outline"
                , Routes.href <| Routes.RepoSettings repo.org repo.name
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks repo.org repo.name Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Routes.href <| Routes.RepoSecrets "native" repo.org repo.name Nothing Nothing
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]
