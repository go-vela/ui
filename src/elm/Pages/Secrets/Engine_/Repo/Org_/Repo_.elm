{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Repo.Org_.Repo_ exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Pager
import Components.Secrets
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (a, text)
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
import Svg.Attributes
import Time
import Utils.Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        }



-- INIT


type alias Model =
    { orgSecrets : WebData (List Vela.Secret)
    , repoSecrets : WebData (List Vela.Secret)
    , pager : List WebLink
    }


init : Shared.Model -> Route { engine : String, org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { orgSecrets = RemoteData.Loading
      , repoSecrets = RemoteData.Loading
      , pager = []
      }
    , Effect.batch
        [ Effect.getOrgSecrets
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetOrgSecretsResponse
            , pageNumber = Nothing
            , perPage = Nothing
            , engine = route.params.engine
            , org = route.params.org
            }
        , Effect.getRepoSecrets
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoSecretsResponse
            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
            , engine = route.params.engine
            , org = route.params.org
            , repo = route.params.repo
            }
        ]
    )



-- UPDATE


type Msg
    = -- SECRETS
      GetOrgSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GetRepoSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GotoPage Int
      -- ALERTS
    | AddAlertCopiedToClipboard String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { engine : String, org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
        GetOrgSecretsResponse response ->
            case response of
                Ok ( _, secrets ) ->
                    ( { model
                        | orgSecrets = RemoteData.Success secrets
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | orgSecrets = Utils.Errors.toFailure error }
                    , Effect.none
                    )

        GetRepoSecretsResponse response ->
            case response of
                Ok ( meta, secrets ) ->
                    ( { model
                        | repoSecrets = RemoteData.Success secrets
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repoSecrets = Utils.Errors.toFailure error }
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
                , Effect.getRepoSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetRepoSecretsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , engine = route.params.engine
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        -- ALERTS
        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.batch
                [ Effect.getOrgSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetOrgSecretsResponse
                    , pageNumber = Nothing
                    , perPage = Nothing
                    , engine = route.params.engine
                    , org = route.params.org
                    }
                , Effect.getRepoSecrets
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetRepoSecretsResponse
                    , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , engine = route.params.engine
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Secrets"
    , body =
        [ Components.Secrets.viewRepoSecrets shared
            { msgs =
                { showCopyAlert = AddAlertCopiedToClipboard
                }
            , engine = route.params.engine
            , key = route.params.org ++ "/" ++ route.params.repo
            , secrets = model.repoSecrets
            , tableButtons =
                Just
                    [ a
                        [ class "button"
                        , class "-outline"
                        , class "button-with-icon"
                        , Util.testAttribute "add-repo-secret"
                        , Route.Path.href <|
                            Route.Path.SecretsEngine_RepoOrg_Repo_Add
                                { engine = route.params.engine
                                , org = route.params.org
                                , repo = route.params.repo
                                }
                        ]
                        [ text "Add Repo Secret"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
                    ]
            }
        , Components.Secrets.viewOrgSecrets shared
            { msgs =
                { showCopyAlert = AddAlertCopiedToClipboard
                }
            , engine = route.params.engine
            , key = route.params.org
            , secrets = model.orgSecrets
            , tableButtons =
                Just
                    [ a
                        [ class "button"
                        , class "-outline"
                        , Route.Path.href <|
                            Route.Path.SecretsEngine_OrgOrg_
                                { engine = route.params.engine
                                , org = route.params.org
                                }
                        , Util.testAttribute "manage-org-secrets"
                        ]
                        [ text "Manage Org Secrets" ]
                    ]
            }
        ]
    }
