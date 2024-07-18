{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Pager exposing (defaultLabels, prevNextLabels, prevNext,view)

import Api.Pagination as Pagination
import FeatherIcons
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, disabled)
import Html.Events exposing (onClick)
import LinkHeader exposing (WebLink)
import Utils.Helpers as Util



-- TYPES


{-| Label : alias for an object representing the possible labels for a pager component.
-}
type alias Labels =
    { previousLabel : String
    , nextLabel : String
    }


{-| defaultLabels : default labels for the pager.
-}
defaultLabels : Labels
defaultLabels =
    { previousLabel = "newer"
    , nextLabel = "older"
    }


{-| prevNextLabels : navigation labels for the pager.
-}
prevNextLabels : Labels
prevNextLabels =
    { previousLabel = "prev"
    , nextLabel = "next"
    }


{-| Props : alias for an object representing properties for the pager component.
-}
type alias Props msg =
    { show : Bool
    , links : List WebLink
    , labels : Labels
    , msg : Pagination.Page -> msg
    }



-- VIEW


{-| view : renders pager buttons with correct state based on number of pages.
-}
view : Props msg -> Html msg
view props =
    let
        linkRels : List LinkHeader.LinkRel
        linkRels =
            List.map .rel props.links

        -- note: list is empty if there's only one page
        isFirst : Bool
        isFirst =
            List.member (LinkHeader.RelNext 2) linkRels

        maybePrevPage : Maybe LinkHeader.LinkRel
        maybePrevPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelPrev _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        maybeNextPage : Maybe LinkHeader.LinkRel
        maybeNextPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelNext _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        isLast : Bool
        isLast =
            case ( maybePrevPage, maybeNextPage ) of
                ( Just (LinkHeader.RelPrev _), Nothing ) ->
                    True

                _ ->
                    False

        nextPage : Int
        nextPage =
            case maybeNextPage of
                Just (LinkHeader.RelNext num) ->
                    num

                _ ->
                    1

        prevPage : Int
        prevPage =
            case maybePrevPage of
                Just (LinkHeader.RelPrev num) ->
                    num

                _ ->
                    1
    in
    if props.show then
        div [ class "pager-actions", class "buttons" ]
            [ button
                [ disabled <| isFirst || (List.length props.links == 0)
                , Util.testAttribute "pager-previous"
                , class "button"
                , class "-outline"
                , class "pager-icon-prev"
                , onClick (props.msg prevPage)
                ]
                [ FeatherIcons.chevronLeft
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
                , text props.labels.previousLabel
                ]
            , button
                [ disabled <| isLast || (List.length props.links == 0)
                , Util.testAttribute "pager-next"
                , class "button"
                , class "-outline"
                , class "pager-icon-next"
                , onClick (props.msg nextPage)
                ]
                [ text props.labels.nextLabel
                , FeatherIcons.chevronRight
                    |> FeatherIcons.withSize 18
                    |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
                ]
            ]

    else
        text ""


{-| prevNext : returns pager state based on number of pages and current page.
-}
prevNext : List WebLink-> (Bool, Bool)
prevNext links =
    let
        linkRels : List LinkHeader.LinkRel
        linkRels =
            List.map .rel links

        -- note: list is empty if there's only one page
        isFirst : Bool
        isFirst =
            List.member (LinkHeader.RelNext 2) linkRels

        maybePrevPage : Maybe LinkHeader.LinkRel
        maybePrevPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelPrev _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        maybeNextPage : Maybe LinkHeader.LinkRel
        maybeNextPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelNext _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        isLast : Bool
        isLast =
            case ( maybePrevPage, maybeNextPage ) of
                ( Just (LinkHeader.RelPrev _), Nothing ) ->
                    True

                _ ->
                    False

    in
        (not <| isFirst || (List.length links == 0), not <| isLast || (List.length links == 0))
   
