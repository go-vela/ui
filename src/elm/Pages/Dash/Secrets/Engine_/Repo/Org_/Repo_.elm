{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Dash.Secrets.Engine_.Repo.Org_.Repo_ exposing (Model, Msg, page, view)

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
import Utils.Errors as Errors
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
        , helpCommands =
            [ { name = "List Repo Secrets"
              , content =
                    "vela get secrets --secret.engine native --secret.type repo --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "secret/get"
              }
            , { name = "List Org Secrets"
              , content =
                    "vela get secrets --secret.engine native --secret.type org --org "
                        ++ route.params.org
              , docs = Just "secret/get"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        }



-- INIT


type alias Model =
    { repoSecrets : WebData (List Vela.Secret)
    , orgSecrets : WebData (List Vela.Secret)
    , pager : List WebLink
    }


init : Shared.Model -> Route { engine : String, org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repoSecrets = RemoteData.Loading
      , orgSecrets = RemoteData.Loading
      , pager = []
      }
    , Effect.batch
        [ Effect.getRepoSecrets
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoSecretsResponse
            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
            , engine = route.params.engine
            , org = route.params.org
            , repo = route.params.repo
            }
        , Effect.getOrgSecrets
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetOrgSecretsResponse
            , pageNumber = Nothing
            , perPage = Nothing
            , engine = route.params.engine
            , org = route.params.org
            }
        ]
    )



-- UPDATE


type Msg
    = -- SECRETS
      GetRepoSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GetOrgSecretsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ))
    | GotoPage Int
      -- ALERTS
    | AddAlertCopiedToClipboard String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { engine : String, org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
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
                    ( { model | repoSecrets = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertNon401
                        }
                    )

        GetOrgSecretsResponse response ->
            case response of
                Ok ( _, secrets ) ->
                    ( { model
                        | orgSecrets = RemoteData.Success secrets
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | orgSecrets = Errors.toFailure error }
                    , Effect.none
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
            , Effect.addAlertSuccess
                { content = "'" ++ contentCopied ++ "' copied to clipboard."
                , addToastIfUnique = False
                , link = Nothing
                }
            )

        -- REFRESH
        Tick options ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        pageNumQuery =
            Dict.get "page" route.query |> Maybe.andThen String.toInt

        pageNum =
            case pageNumQuery of
                Just n ->
                    n

                Nothing ->
                    1
    in
    { title = "Secrets" ++ Util.pageToString (Dict.get "page" route.query)
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
                            Route.Path.Dash_Secrets_Engine__Repo_Org__Repo__Add
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
                    , Components.Pager.view
                        { show = True
                        , links = model.pager
                        , labels = Components.Pager.prevNextLabels
                        , msg = GotoPage
                        }
                    ]
            , pageNumber = pageNum
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
                            Route.Path.Dash_Secrets_Engine__Org_Org_
                                { engine = route.params.engine
                                , org = route.params.org
                                }
                        , Util.testAttribute "manage-org-secrets"
                        ]
                        [ text "Manage Org Secrets" ]
                    ]
            , pageNumber = 1
            }
        ]
    }
