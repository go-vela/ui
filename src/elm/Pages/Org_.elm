{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_ exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Loading
import Components.Pager
import Components.Repo
import Dict
import Effect exposing (Effect)
import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
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
        , helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Nothing )
            ]
        , org = route.params.org
        }



-- INIT


type alias Model =
    { repos : WebData (List Vela.Repository)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repos = RemoteData.Loading
      , pager = []
      }
    , Effect.getOrgRepos
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetOrgReposResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        }
    )



-- UPDATE


type Msg
    = -- REPOS
      GetOrgReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Repository ))
    | GotoPage Int
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
                Ok ( meta, repos ) ->
                    ( { model
                        | repos = RemoteData.Success repos
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repos = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.pushRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getOrgRepos
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgReposResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    }
                ]
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
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String } -> Model -> View Msg
view shared route model =
    { title = "Repos" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ Html.caption
            [ class "builds-caption"
            ]
            [ Html.span [] []
            , Components.Pager.view
                { show = True
                , links = model.pager
                , labels = Components.Pager.prevNextLabels
                , msg = GotoPage
                }
            ]
        , case model.repos of
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
                    div [] <|
                        List.map
                            (\repository ->
                                Components.Repo.view
                                    shared
                                    { toggleFavoriteMsg = ToggleFavorite
                                    , org = repository.org
                                    , repo = repository.name
                                    , favorites = RemoteData.unwrap [] .favorites shared.user
                                    , filtered = False
                                    }
                            )
                            repos

            RemoteData.Loading ->
                Components.Loading.viewSmallLoader

            RemoteData.NotAsked ->
                Components.Loading.viewSmallLoader

            RemoteData.Failure _ ->
                div [ Util.testAttribute "repos-error" ]
                    [ p []
                        [ text "There was an error fetching repos, please refresh or try again later!"
                        ]
                    ]
        , Components.Pager.view
            { show = True
            , links = model.pager
            , labels = Components.Pager.prevNextLabels
            , msg = GotoPage
            }
        ]
    }
