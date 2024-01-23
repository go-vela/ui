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
import Route.Path
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
                        , Route.Path.href Route.Path.AccountSourceRepos
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
            div [ Util.testAttribute "repos-error" ]
                [ p []
                    [ text "There was an error fetching repos, please refresh or try again later!"
                    ]
                ]


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

                -- , Routes.href <| Routes.RepoSettings repo.org repo.name
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-audit"
                , Route.Path.href <| Route.Path.Org_Repo_Audit { org = repo.org, repo = repo.name }
                ]
                [ text "Audit" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Route.Path.href <| Route.Path.Org_Repo_Secrets { org = repo.org, repo = repo.name }
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Route.Path.href <| Route.Path.Org_Repo_ { org = repo.org, repo = repo.name }
                ]
                [ text "View" ]
            ]
        ]
