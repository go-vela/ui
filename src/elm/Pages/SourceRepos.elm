{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.SourceRepos exposing (Msgs, PartialModel, view)

import Dict
import Errors exposing (viewResourceError)
import Favorites
    exposing
        ( ToggleFavorite
        , isFavorited
        , starToggle
        )
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import Search
    exposing
        ( Search
        , filterRepo
        , repoSearchBarGlobal
        , repoSearchBarLocal
        , searchFilterGlobal
        , searchFilterLocal
        , shouldSearch
        )
import Util
import Vela
    exposing
        ( CurrentUser
        , EnableRepo
        , EnableRepos
        , Org
        , RepoSearchFilters
        , Repositories
        , Repository
        , SourceRepositories
        )



-- TYPES


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel =
    { user : WebData CurrentUser
    , sourceRepos : WebData SourceRepositories
    , filters : RepoSearchFilters
    }


{-| Msgs : record containing msgs routeable to Main.elm
-}
type alias Msgs msg =
    { search : Search msg
    , enableRepo : EnableRepo msg
    , enableRepos : EnableRepos msg
    , toggleFavorite : ToggleFavorite msg
    }



-- VIEW


{-| view : takes model and renders account page for enabling repos/adding them to overview
-}
view : PartialModel -> Msgs msg -> Html msg
view model actions =
    let
        ( sourceRepos, filters ) =
            ( model.sourceRepos, model.filters )

        loading =
            div []
                [ h1 []
                    [ text "Loading your Repositories"
                    , span [ class "loading-ellipsis" ] []
                    ]
                , p []
                    [ text <|
                        "Hang tight while we grab the list of repositories that you have access to from Github. If you have access to "
                            ++ "a lot of organizations and repositories this might take a little while."
                    ]
                ]
    in
    case sourceRepos of
        RemoteData.Success repos ->
            div [ class "source-repos", Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal filters actions.search
                , viewSourceRepos model repos actions
                ]

        RemoteData.Loading ->
            loading

        RemoteData.NotAsked ->
            loading

        RemoteData.Failure _ ->
            viewResourceError { resourceLabel = "your available repositories", testLabel = "repos" }


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : PartialModel -> SourceRepositories -> Msgs msg -> Html msg
viewSourceRepos model sourceRepos actions =
    let
        filters =
            model.filters
    in
    if shouldSearch <| searchFilterGlobal filters then
        -- Search and render repos using the global filter
        searchReposGlobal model sourceRepos actions.enableRepo actions.toggleFavorite

    else
        -- Render repos normally
        sourceRepos
            |> Dict.toList
            |> Util.filterEmptyLists
            |> List.map (\( org, repos_ ) -> viewSourceOrg model.user filters org repos_ actions)
            |> div [ class "repo-list" ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : WebData CurrentUser -> RepoSearchFilters -> Org -> Repositories -> Msgs msg -> Html msg
viewSourceOrg user filters org repos actions =
    let
        ( search, enableRepo, toggleFavorite ) =
            ( actions.search, actions.enableRepo, actions.toggleFavorite )

        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org filters then
                -- Search and render repos using the global filter
                searchReposLocal user org filters repos enableRepo toggleFavorite

            else
                -- Render repos normally
                ( repos, False, List.map (viewSourceRepo user enableRepo toggleFavorite) repos )
    in
    viewSourceOrgDetails filters org repos_ filtered content search actions.enableRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> EnableRepos msg -> Html msg
viewSourceOrgDetails filters org repos filtered content search enableRepos =
    details [ class "details", class "-with-border" ] <|
        viewSourceOrgSummary filters org repos filtered content search enableRepos


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> EnableRepos msg -> List (Html msg)
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
viewSourceRepo : WebData CurrentUser -> EnableRepo msg -> ToggleFavorite msg -> Repository -> Html msg
viewSourceRepo user enableRepo toggleFavorite repo =
    let
        favorited =
            isFavorited user <| repo.org ++ "/" ++ repo.name
    in
    div [ class "item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , enableRepoButton repo enableRepo toggleFavorite favorited
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : EnableRepo msg -> ToggleFavorite msg -> Repository -> Bool -> Html msg
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
enableReposButton : Org -> Repositories -> Bool -> EnableRepos msg -> Html msg
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
enableRepoButton : Repository -> EnableRepo msg -> ToggleFavorite msg -> Bool -> Html msg
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
                    [ starToggle repo.org repo.name toggleFavorite <| favorited
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
                        , Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing Nothing
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
searchReposGlobal : PartialModel -> SourceRepositories -> EnableRepo msg -> ToggleFavorite msg -> Html msg
searchReposGlobal model repos enableRepo toggleFavorite =
    let
        ( user, filters ) =
            ( model.user, model.filters )

        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.map (\( _, repos_ ) -> repos_)
                |> List.concat
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo enableRepo toggleFavorite repo <| isFavorited user <| repo.org ++ "/" ++ repo.name)

        else
            -- No repos matched the search
            [ div [ class "item" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : WebData CurrentUser -> Org -> RepoSearchFilters -> Repositories -> EnableRepo msg -> ToggleFavorite msg -> ( Repositories, Bool, List (Html msg) )
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
