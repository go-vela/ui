{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments exposing (..)

import Api.Pagination
import Auth
import Components.Loading
import Components.Pager
import Components.Svgs
import Components.Table
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , rows
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Time
import Url
import Utils.Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


repoArgs : Route { org : String, repo : String } -> String
repoArgs route =
    "--org " ++ route.params.org ++ " --repo " ++ route.params.repo


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "List Deployments"
              , content = "vela get deployments " ++ repoArgs route
              , docs = Just "deployment/get"
              }
            , { name = "View Deployment"
              , content = "vela view deployment " ++ repoArgs route ++ "--deployment 1"
              , docs = Just "deployment/get"
              }
            ]
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
    { repo : WebData Vela.Repository
    , deployments : WebData (List Vela.Deployment)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { deployments = RemoteData.Loading
      , repo = RemoteData.Loading
      , pager = []
      }
    , Effect.batch
        [ Effect.getRepo
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoResponse
            , org = route.params.org
            , repo = route.params.repo
            }
        , Effect.getRepoDeployments
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoDeploymentsResponse
            , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
            , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
            , org = route.params.org
            , repo = route.params.repo
            }
        ]
    )



-- UPDATE


type Msg
    = -- REPO
      GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
      -- DEPLOYMENTS
    | GetRepoDeploymentsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Deployment ))
    | GotoPage Int
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- DEPLOYMENTS
        GetRepoDeploymentsResponse response ->
            case response of
                Ok ( meta, deployments ) ->
                    ( { model
                        | deployments = RemoteData.Success deployments
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | deployments = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.replaceRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getRepoDeployments
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetRepoDeploymentsResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        -- REPO
        GetRepoResponse response ->
            case response of
                Ok ( meta, repo ) ->
                    ( { model
                        | repo = RemoteData.Success repo
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repo = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getRepoDeployments
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetRepoDeploymentsResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                , org = route.params.org
                , repo = route.params.repo
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Deployments" ++ Util.pageToString (Dict.get "page" route.query)
    , body =
        [ viewDeployments shared model route
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }


{-| viewDeployments : renders a list of deployments
-}
viewDeployments : Shared.Model -> Model -> Route { org : String, repo : String } -> Html Msg
viewDeployments shared model route =
    let
        actions =
            Just <|
                div [ class "buttons" ]
                    [ a
                        [ class "button"
                        , class "-outline"
                        , class "button-with-icon"
                        , Util.testAttribute "add-deployment"
                        , Route.Path.href <|
                            Route.Path.Org_Repo_DeploymentsAdd { org = route.params.org, repo = route.params.repo }
                        ]
                        [ text "Add Deployment"
                        , FeatherIcons.plus
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                        ]
                    , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
                    ]

        ( noRowsView, rows ) =
            let
                viewHttpError e =
                    span [ Util.testAttribute "repo-deployments-error" ]
                        [ text <|
                            case e of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No deployments found for this repo, most likely due to not having access to the source control repo"

                                        _ ->
                                            "No deployments found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No deployments found for this repo, there was an error with the server"
                        ]
            in
            case ( model.repo, model.deployments ) of
                ( RemoteData.Success r, RemoteData.Success d ) ->
                    ( text "No deployments found for this repo"
                    , deploymentsToRows shared r d
                    )

                ( RemoteData.Failure error, _ ) ->
                    ( viewHttpError error, [] )

                ( _, RemoteData.Failure error ) ->
                    ( viewHttpError error, [] )

                _ ->
                    ( Components.Loading.viewSmallLoader, [] )

        cfg =
            Components.Table.Config
                "Deployments"
                "deployments"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div []
        [ Components.Table.view cfg
        ]



-- TABLE


{-| deploymentsToRows : takes list of deployments and produces list of Table rows
-}
deploymentsToRows : Shared.Model -> Vela.Repository -> List Vela.Deployment -> Components.Table.Rows Vela.Deployment Msg
deploymentsToRows shared repo deployments =
    List.map (\deployment -> Components.Table.Row deployment (viewDeployment shared repo)) deployments


{-| tableHeaders : returns table headers for deployments table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Just "table-icon", "status" )
    , ( Nothing, "number" )
    , ( Nothing, "target" )
    , ( Nothing, "commit" )
    , ( Nothing, "ref" )
    , ( Nothing, "description" )
    , ( Nothing, "builds" )
    , ( Nothing, "created by" )
    , ( Nothing, "created at" )
    , ( Nothing, "redeploy" )
    ]


{-| viewDeployment : takes deployment and renders a table row
-}
viewDeployment : Shared.Model -> Vela.Repository -> Vela.Deployment -> Html Msg
viewDeployment shared repo deployment =
    tr [ Util.testAttribute <| "deployments-row", class "-success" ]
        [ Components.Table.viewIconCell
            { dataLabel = "status"
            , parentClassList = []
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ Components.Svgs.hookSuccess
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "number"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| String.fromInt deployment.number
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "target"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text deployment.target
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "commit"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ a [ href <| Util.buildRefURL repo.clone deployment.commit ]
                    [ text <| Util.trimCommitHash deployment.commit ]
                ]
            }
        , Components.Table.viewListItemCell
            { dataLabel = "ref"
            , parentClassList = [ ( "ref", True ) ]
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ text deployment.ref
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "description"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text deployment.description
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "builds"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ viewDeploymentBuildsLinks deployment
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "created by"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| deployment.created_by
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "created at"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault shared.zone deployment.created_at
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = ""
            , parentClassList = []
            , itemClassList = []
            , children =
                [ a
                    [ class "redeploy-link"
                    , attribute "aria-label" <| "redeploy deployment " ++ String.fromInt deployment.id
                    , Route.href <|
                        { path = Route.Path.Org_Repo_DeploymentsAdd { org = repo.org, repo = repo.name }
                        , query =
                            Dict.fromList <|
                                [ ( "target", deployment.target )
                                , ( "ref", deployment.ref )
                                , ( "description", deployment.description )
                                , ( "task", deployment.task )
                                ]
                                    ++ Maybe.Extra.unwrap
                                        []
                                        (\parameters ->
                                            [ ( "parameters"
                                              , String.join ","
                                                    (List.map
                                                        (\parameter ->
                                                            Url.percentEncode <| parameter.key ++ "=" ++ parameter.value
                                                        )
                                                        parameters
                                                    )
                                              )
                                            ]
                                        )
                                        deployment.payload
                        , hash = Nothing
                        }
                    , Util.testAttribute "redeploy-deployment"
                    ]
                    [ text "Redeploy"
                    ]
                ]
            }
        ]


viewDeploymentBuildsLinks : Vela.Deployment -> Html msg
viewDeploymentBuildsLinks deployment =
    deployment.builds
        |> List.map
            (\build ->
                a
                    [ href build.link ]
                    [ text
                        (build.link
                            |> String.split "/"
                            |> List.reverse
                            |> List.head
                            |> Maybe.withDefault ""
                            |> String.append "#"
                        )
                    ]
            )
        |> List.intersperse (text ", ")
        |> div []
