{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Account.SourceRepos_ exposing (..)

import Api.Api as Api
import Api.Operations_
import Auth
import Components.Favorites as Favorites
import Components.Search as Search
    exposing
        ( Search
        , filterRepo
        , repoSearchBarGlobal
        , repoSearchBarLocal
        , searchFilterGlobal
        , searchFilterLocal
        , shouldSearch
        )
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , details
        , div
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , disabled
        )
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (CurrentUser, Org, RepoSearchFilters, Repository, SourceRepositories)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init
        , update = update shared
        , subscriptions = subscriptions
        , view = view shared
        }
        |> Page.withLayout (toLayout user shared)



-- LAYOUT


toLayout : Auth.User -> Shared.Model -> Model -> Layouts.Layout Msg
toLayout user shared model =
    Layouts.Default
        { navButtons =
            [ button
                [ classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick (GetUserSourceRepos True)
                , disabled (model.sourceRepos == Loading)
                , Util.testAttribute "refresh-source-repos"
                ]
                [ case model.sourceRepos of
                    Loading ->
                        text "Loading…"

                    _ ->
                        text "Refresh List"
                ]
            ]
        , utilButtons = []
        }



-- INIT


type alias Model =
    { searchFilters : RepoSearchFilters
    , sourceRepos : WebData SourceRepositories
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { searchFilters = Dict.empty
      , sourceRepos = NotAsked
      }
    , Effect.batch
        [ Effect.getCurrentUser {}
        , Effect.sendMsg (GetUserSourceRepos False)
        ]
    )



-- UPDATE


type Msg
    = NoOp
    | GetUserSourceRepos Bool
    | GetUserSourceReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, SourceRepositories ))
    | ToggleFavorite Org (Maybe String)
    | EnableRepos (List Repository)
    | EnableRepo Repository
    | EnableRepoResponse Repository (Result (Http.Detailed.Error String) ( Http.Metadata, Repository ))
    | UpdateSearchFilter Org String


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        GetUserSourceRepos isReload ->
            ( { model
                | sourceRepos =
                    if isReload || model.sourceRepos == NotAsked then
                        Loading

                    else
                        model.sourceRepos
              }
            , Api.try
                GetUserSourceReposResponse
                (Api.Operations_.getUserSourceRepos shared.velaAPI shared.session)
                |> Effect.sendCmd
            )

        GetUserSourceReposResponse response ->
            case response of
                Ok ( _, repositories ) ->
                    ( { model
                        | sourceRepos = RemoteData.succeed repositories
                      }
                    , Effect.focusOn { target = "global-search-input" }
                    )

                Err error ->
                    ( { model
                        | sourceRepos = Errors.toFailure error
                      }
                    , Effect.handleHttpError { httpError = error }
                    )

        ToggleFavorite org maybeRepo ->
            ( model
            , Effect.updateFavorites { org = org, maybeRepo = maybeRepo, updateType = Favorites.Toggle }
            )

        EnableRepos repos ->
            ( model
            , repos
                |> List.map EnableRepo
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        EnableRepo repo ->
            ( { model
                | sourceRepos = Vela.enableUpdate repo Loading model.sourceRepos

                -- todo: need this moved to the repo settings page
                -- , repo = updateRepoEnabling Vela.Enabling rm
              }
            , Effect.enableRepo
                { baseUrl = shared.velaAPI
                , session = shared.session
                , repo = repo
                , onResponse = EnableRepoResponse repo
                }
            )

        EnableRepoResponse repo response ->
            case response of
                Ok ( _, enabledRepo ) ->
                    ( { model
                        | sourceRepos = Vela.enableUpdate enabledRepo (RemoteData.succeed True) model.sourceRepos

                        -- todo: need this moved to the repo settings page
                        -- , repo = updateRepoEnabling Vela.Enabled rm
                      }
                    , Effect.batch
                        [ Effect.addAlertSuccess
                            { content = enabledRepo.full_name ++ " enabled.", addToastIfUnique = True }
                        , Effect.updateFavorites { org = enabledRepo.org, maybeRepo = Just enabledRepo.name, updateType = Favorites.Add }
                        ]
                    )

                Err error ->
                    (case error of
                        Http.Detailed.BadStatus metadata _ ->
                            case metadata.statusCode of
                                409 ->
                                    ( RemoteData.succeed True, Effect.none )

                                _ ->
                                    ( Errors.toFailure error, Effect.handleHttpError { httpError = error } )

                        _ ->
                            ( Errors.toFailure error, Effect.handleHttpError { httpError = error } )
                    )
                        |> Tuple.mapFirst (\m -> Vela.enableUpdate repo m model.sourceRepos)
                        |> Tuple.mapFirst (\m -> { model | sourceRepos = m })

        UpdateSearchFilter org searchBy ->
            ( { model
                | searchFilters =
                    Dict.update org (\_ -> Just searchBy) model.searchFilters
              }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user with repos fetched from source control
-}
view : Shared.Model -> Model -> View Msg
view shared model =
    let
        body =
            div [ Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal model.searchFilters UpdateSearchFilter
                , viewSourceRepos shared model
                ]
    in
    { title = "Pages.Account.SourceRepos_"
    , body =
        [ body
        ]
    }


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : Shared.Model -> Model -> Html Msg
viewSourceRepos shared model =
    case model.sourceRepos of
        RemoteData.Success repos ->
            if shouldSearch <| searchFilterGlobal model.searchFilters then
                searchReposGlobal shared model repos EnableRepo ToggleFavorite

            else
                repos
                    |> Dict.toList
                    |> Util.filterEmptyLists
                    |> List.map (\( org, repos_ ) -> viewSourceOrg shared.user model.searchFilters org repos_)
                    |> span []

        RemoteData.Loading ->
            viewLoadingSourceOrgs

        RemoteData.NotAsked ->
            viewLoadingSourceOrgs

        RemoteData.Failure _ ->
            viewErrorSourceOrg


{-| viewLoadingSourceOrgs : renders 8 source org loading skeletons
-}
viewLoadingSourceOrgs : Html Msg
viewLoadingSourceOrgs =
    span [] <|
        List.Extra.initialize 8 viewLoadingSourceOrg


{-| viewLoadingSourceOrg : renders a loading indicator in the form of a source org skeleton
-}
viewLoadingSourceOrg : Int -> Html Msg
viewLoadingSourceOrg idx =
    let
        icon =
            FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml []

        content =
            if idx == 0 then
                span []
                    [ text "Loading all source control repositories you have access to, this may take awhile"
                    , span [ class "loading-ellipsis" ] []
                    ]

            else
                text ""

        animation =
            div [ class "loading-shimmer" ] []
    in
    div [ class "loading-skeleton" ]
        [ animation
        , div []
            [ icon
            , content
            ]
        ]


{-| viewErrorSourceOrg : renders an error in the form of a source org when unable to fetch source repositories
-}
viewErrorSourceOrg : Html Msg
viewErrorSourceOrg =
    let
        icon =
            FeatherIcons.x |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml []

        content =
            text "There was an error fetching your available repositories, please refresh or try again later!"
    in
    div [ class "loading-skeleton" ]
        [ div []
            [ icon
            , content
            ]
        ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : WebData CurrentUser -> RepoSearchFilters -> Org -> List Repository -> Html Msg
viewSourceOrg user filters org repos =
    let
        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org filters then
                -- Search and render repos using the global filter
                searchReposLocal user org filters repos EnableRepo ToggleFavorite

            else
                -- Render repos normally
                ( repos, False, List.map (viewSourceRepo user EnableRepo ToggleFavorite) repos )
    in
    viewSourceOrgDetails filters org repos_ filtered content UpdateSearchFilter EnableRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : RepoSearchFilters -> Org -> List Repository -> Bool -> List (Html msg) -> Search msg -> Vela.EnableRepos msg -> Html msg
viewSourceOrgDetails filters org repos filtered content search enableRepos =
    details [ class "details", class "-with-border" ] <|
        viewSourceOrgSummary filters org repos filtered content search enableRepos


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : RepoSearchFilters -> Org -> List Repository -> Bool -> List (Html msg) -> Search msg -> Vela.EnableRepos msg -> List (Html msg)
viewSourceOrgSummary filters org repos filtered content search enableRepos =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ text org
        , viewRepoCount repos
        , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
        ]
        :: div [ class "form-controls", class "-no-x-pad" ]
            [ repoSearchBarLocal filters org search
            , enableReposButton org repos filtered enableRepos
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos
viewSourceRepo uses model.sourceRepos and enableRepoButton to determine the state of each specific 'Enable' button
-}
viewSourceRepo : WebData CurrentUser -> Vela.EnableRepo msg -> Favorites.UpdateFavorites msg -> Repository -> Html msg
viewSourceRepo user enableRepo toggleFavorite repo =
    let
        favorited =
            Favorites.isFavorited user <| repo.org ++ "/" ++ repo.name
    in
    div [ class "item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , enableRepoButton repo enableRepo toggleFavorite favorited
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : Vela.EnableRepo msg -> Favorites.UpdateFavorites msg -> Repository -> Bool -> Html msg
viewSearchedSourceRepo enableRepo toggleFavorite repo favorited =
    div [ class "item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div []
            [ text <| repo.org ++ "/" ++ repo.name ]
        , enableRepoButton repo enableRepo toggleFavorite favorited
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ text <| (String.fromInt <| List.length repos) ++ " repos" ]


{-| enableReposButton : takes List of repos and renders a button to enable them all at once, texts depends on user input filter
-}
enableReposButton : Org -> List Repository -> Bool -> Vela.EnableRepos msg -> Html msg
enableReposButton org repos filtered enableRepos =
    button [ class "button", class "-outline", Util.testAttribute <| "enable-org-" ++ org, onClick (enableRepos repos) ]
        [ text <|
            if filtered then
                "Enable Results"

            else
                "Enable All"
        ]


{-| enableRepoButton : builds action button for enabling single repos
-}
enableRepoButton : Repository -> Vela.EnableRepo msg -> Favorites.UpdateFavorites msg -> Bool -> Html msg
enableRepoButton repo enableRepo toggleFavorite favorited =
    case repo.enabled of
        RemoteData.NotAsked ->
            button
                [ class "button"
                , Util.testAttribute <| String.join "-" [ "enable", repo.org, repo.name ]
                , onClick (enableRepo repo)
                ]
                [ text "Enable" ]

        RemoteData.Loading ->
            button
                [ class "button"
                , class "-outline"
                , class "-loading"
                , Util.testAttribute <| String.join "-" [ "loading", repo.org, repo.name ]
                ]
                [ text "Enabling", span [ class "loading-ellipsis" ] [] ]

        RemoteData.Failure _ ->
            button
                [ class "button"
                , class "-outline"
                , class "-failure"
                , class "-animate-rotate"
                , Util.testAttribute <| String.join "-" [ "failed", repo.org, repo.name ]
                , onClick (enableRepo repo)
                ]
                [ FeatherIcons.refreshCw |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]

        RemoteData.Success enabledStatus ->
            if enabledStatus then
                div [ class "buttons" ]
                    [ Favorites.starToggle repo.org repo.name toggleFavorite <| favorited
                    , button
                        [ class "button"
                        , class "-outline"
                        , class "-success"
                        , attribute "tabindex" "-1" -- in this scenario we are merely showing state, this is not interactive
                        , Util.testAttribute <| String.join "-" [ "enabled", repo.org, repo.name ]
                        ]
                        [ FeatherIcons.check |> FeatherIcons.withSize 18 |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Enabled" ]
                    , a
                        [ class "button"
                        , Util.testAttribute <| String.join "-" [ "view", repo.org, repo.name ]

                        -- , Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing Nothing
                        ]
                        [ text "View" ]
                    ]

            else
                button
                    [ class "button"
                    , class "-outline"
                    , class "-failure"
                    , Util.testAttribute <| String.join "-" [ "failed", repo.org, repo.name ]
                    , onClick (enableRepo repo)
                    ]
                    [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : Shared.Model -> Model -> SourceRepositories -> Vela.EnableRepo msg -> Favorites.UpdateFavorites msg -> Html msg
searchReposGlobal shared model repos enableRepo toggleFavorite =
    let
        ( user, filters ) =
            ( shared.user, model.searchFilters )

        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.concatMap (\( _, repos_ ) -> repos_)
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo enableRepo toggleFavorite repo <| Favorites.isFavorited user <| repo.org ++ "/" ++ repo.name)

        else
            -- No repos matched the search
            [ div [ class "item" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : WebData CurrentUser -> Org -> RepoSearchFilters -> List Repository -> Vela.EnableRepo msg -> Favorites.UpdateFavorites msg -> ( List Repository, Bool, List (Html msg) )
searchReposLocal user org filters repos enableRepo toggleFavorite =
    -- Filter the repos if the user typed more than 2 characters
    let
        filteredRepos =
            List.filter (\repo -> filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map (viewSourceRepo user enableRepo toggleFavorite) filteredRepos

      else
        [ div [ class "item" ] [ text "No results" ] ]
    )
