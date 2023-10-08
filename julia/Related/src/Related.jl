module Related

using JSON3
using StructTypes
using Dates
using StaticArrays

export relatedIO

# warmup is done by hyperfine

function relatedIO()
    json_string = read("../posts.json", String)
    posts = JSON3.read(json_string, Vector{PostData})

    start = now()
    all_related_posts = related(posts)
    println("Processing time (w/o IO): $(now() - start)")


    open("../related_posts_julia.json", "w") do f
        JSON3.write(f, all_related_posts)
    end
end

struct PostData
    _id::String
    title::String
    tags::Vector{String}
end

struct RelatedPost
    _id::String
    tags::Vector{String}
    related::SVector{5,PostData}
end

StructTypes.StructType(::Type{PostData}) = StructTypes.Struct()

function fastmaxindex!(xs::Vector{Int64}, topn, maxn, maxv)
    maxn .= 1
    maxv .= 0
    top = maxv[1]
    for (i, x) in enumerate(xs)
        if x > top
            maxv[1] = x
            maxn[1] = i
            for j in 2:topn
                if maxv[j-1] > maxv[j]
                    maxv[j-1], maxv[j] = maxv[j], maxv[j-1]
                    maxn[j-1], maxn[j] = maxn[j], maxn[j-1]
                end
            end
            top = maxv[1]
        end
    end

    reverse!(maxn)

    return maxn
end

function related(posts)
    topn = 5
    # key is every possible "tag" used in all posts
    # value is indicies of all "post"s that used this tag
    tagmap = Dict{String,Vector{Int64}}()
    for (idx, post) in enumerate(posts)
        for tag in post.tags
            if !haskey(tagmap, tag)
                tagmap[tag] = Vector{Int64}()
            end
            push!(tagmap[tag], idx)
        end
    end

    relatedposts = Vector{RelatedPost}(undef, length(posts))
    taggedpostcount = Vector{Int64}(undef, length(posts))

    maxn = MVector{topn, Int64}(undef)
    maxv = MVector{topn, Int64}(undef)

    for (i, post) in enumerate(posts)
        taggedpostcount .= 0
        # for each post (`i`-th)
        # and every tag used in the `i`-th post
        # give all related post +1 in `taggedpostcount` shadow vector
        for tag in post.tags
            for idx in tagmap[tag]
                taggedpostcount[idx] += 1
            end
        end

        # don't self count
        taggedpostcount[i] = 0

        fastmaxindex!(taggedpostcount, topn, maxn, maxv)

        relatedpost = RelatedPost(post._id, post.tags, SVector{topn}(@view posts[maxn]))
        relatedposts[i] = relatedpost
    end

    return relatedposts
end

relatedIO()

end
