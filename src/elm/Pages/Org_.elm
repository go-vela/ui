{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_ exposing (Model, Msg, page, view)

import Auth
import Components.Repo
import Effect exposing (Effect)
import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Org
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , org = route.params.org
        }



-- INIT


type alias Model =
    { repos : WebData (List Vela.Repository)
    }


init : Shared.Model -> Route { org : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repos = RemoteData.Loading
      }
    , Effect.getOrgRepos
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetOrgReposResponse
        , org = route.params.org
        }
    )



-- UPDATE


type Msg
    = -- REPOS
      GetOrgReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Repository ))
      -- FAVORITES
    | ToggleFavorite Vela.Org (Maybe Vela.Repo)
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- REPOS
        GetOrgReposResponse response ->
            case response of
                Ok ( _, repos ) ->
                    ( { model | repos = RemoteData.Success repos }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repos = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        -- FAVORITES
        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.updateFavorites { org = org, maybeRepo = maybeRepo, updateType = Favorites.Toggle }
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getOrgRepos
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetOrgReposResponse
                , org = route.params.org
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String } -> Model -> View Msg
view shared route model =
    { title = "Repos"
    , body =
        [ case model.repos of
            RemoteData.Success repos ->
                if List.length repos == 0 then
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
                    div [] (List.map (\repository -> viewRepo shared (RemoteData.unwrap [] .favorites shared.user) False repository.org repository.name) repos)

            RemoteData.Loading ->
                Util.largeLoader

            RemoteData.NotAsked ->
                Util.largeLoader

            RemoteData.Failure _ ->
                div [ Util.testAttribute "repos-error" ]
                    [ p []
                        [ text "There was an error fetching repos, please refresh or try again later!"
                        ]
                    ]
        ]
    }


{-| viewRepo : renders row of repos with action buttons
-}
viewRepo : Shared.Model -> List String -> Bool -> String -> String -> Html Msg
viewRepo shared favorites filtered org repo =
    Components.Repo.view
        shared
        { toggleFavoriteMsg = ToggleFavorite
        , org = org
        , repo = repo
        , favorites = favorites
        , filtered = False
        }
