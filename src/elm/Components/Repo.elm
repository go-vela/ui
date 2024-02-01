{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Repo exposing (view)

import Components.Favorites
import Html exposing (Html, a, div, text)
import Html.Attributes exposing (class)
import Route.Path
import Shared
import Utils.Favorites as Favorites
import Utils.Helpers as Util


type alias Props msg =
    { toggleFavoriteMsg : Favorites.UpdateFavorites msg
    , org : String
    , repo : String
    , favorites : List String
    , filtered : Bool
    }


view : Shared.Model -> Props msg -> Html msg
view shared { toggleFavoriteMsg, org, repo, favorites, filtered } =
    let
        fullname =
            org ++ "/" ++ repo

        name =
            if filtered then
                fullname

            else
                repo
    in
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text name ]
        , div [ class "buttons" ]
            [ Components.Favorites.viewStarToggle
                { msg = toggleFavoriteMsg
                , user = shared.user
                , org = org
                , repo = repo
                }
            , a
                [ class "button"
                , class "-outline"
                , Route.Path.href <| Route.Path.Org_Repo_Settings { org = org, repo = repo }
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-hooks"
                , Route.Path.href <| Route.Path.Org_Repo_Audit { org = org, repo = repo }
                ]
                [ text "Audit" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Route.Path.href <| Route.Path.Org_Repo_Secrets { org = org, repo = repo, engine = "native" }
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Route.Path.href <| Route.Path.Org_Repo_ { org = org, repo = repo }
                ]
                [ text "View" ]
            ]
        ]
