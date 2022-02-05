# based on https://perfectionatic.org/?p=753
#
using ProgressBars

words = readlines(download("https://www-cs-faculty.stanford.edu/~knuth/sgb-words.txt"))


function update_constraints_by_response!(word, response, let_in_pos, let_not_in_pos, let_not_in_word)
    for i in eachindex(response)
        c = response[i]
        if c=='2'
            let_in_pos[i]=word[i]
        elseif c=='1'
            let_not_in_pos[word[i]] = push!(get(let_not_in_pos,word[i],Int[]),i)
        else
            push!(let_not_in_word,word[i])
        end
    end
end

function word_set_reduction!(word_set, let_in_pos, let_not_in_pos, let_not_in_word)
    filter!(w->all(w[r[1]]==r[2] for r in let_in_pos), word_set)
    filter!(w->all(occursin(s[1],w) && all(w[p]!=s[1] for p in s[2]) for s in let_not_in_pos), word_set)
    filter!(w->all(!occursin(c,w[setdiff(1:5,keys(let_in_pos))]) for c in setdiff(let_not_in_word,keys(let_not_in_pos))), word_set)
end

function predict_best_word(word_set, let_in_pos, let_not_in_pos, let_not_in_word;cutoff=20,score_base=1.1,strategy=:letter_freq,verbose=true)
    if strategy == :letter_freq
        # first strategy: maybe best to find words with the highest density of missing letters, ranked by frequency
        letters = ['e','t','a','o','i','n','s','r','h','d','l','u','c','m','f','y','w','g','p','b','v','k','x','q','j','z'] # in order of frequency in english
        filter!(w-> (w ∉ values(let_in_pos) && w ∉ keys(let_not_in_pos) && w ∉ let_not_in_word),letters)
        if verbose
            println("Remaining letters, in order of frequency: $(string(letters...))")
        end
        search_set = length(word_set) > cutoff ? words : word_set
        # rank words
        ranking = zeros(length(search_set))
        for (j,w) in enumerate(search_set)
            ranking[j] = 0
            for (i,l) in enumerate(reverse(letters))
                if l in w
                    ranking[j] += score_base^i
                end
            end
        end
        sorted = sortperm(ranking)
        return search_set[sorted[end]]
    elseif strategy == :random
        return rand(word_set)
    else
        return "Unknown strategy: $strategy"
    end
end


function score_word(word,true_word)
    result = ['0','0','0','0','0']
    for i in 1:5
        if word[i] == true_word[i]
            result[i] = '2'
        elseif word[i] in true_word
            result[i] = '1'
        end
    end
    return string(result...)
end

function pretty_print_response(word,result)
    for i in 1:5
        color = :default
        if result[i] == '1'
            color = :light_yellow
        elseif result[i] == '2'
            color = :light_green
        end
        printstyled(word[i];color=color)
    end
    print("\n")
end


wordle_answers = [
                  "super",
                  "wrung",
                  "perky",
                  "pleat",
                  "shard",
                  "moist",
                  "those",
                  "rebus",
                  "boost",
                  "truss",
                  "siege",
                  "tiger",
                  "banal",
                  "slump",
                  "crank",
                  "gorge",
                  "query",
                  "drink",
                  "favor",
                  "abbey",
                  "tangy",
                  "panic",
                  "solar",
                  "shire",
                  "proxy",
                  "point",
                  "robot",
                  "prick",
                  "wince",
                  "crimp",
                  "knoll",
                  "sugar",
                  "whack",
                  "mount",
                  "perky",
                  "could",
                  "wrung",
                  "light",
]


words = union(wordle_answers,words)

function wordle_cheater()
    let_in_pos = Dict{Int,Char}()
    let_not_in_pos = Dict{Char,Vector{Int}}()
    let_not_in_word = Set{Char}()
    word_set = copy(words)
    print("Enter your starting word [default: reast] :")
    word = readline()
    if length(word) == 0
        word = "reast"
    end
    while length(word_set) > 1
        print("Enter your response (Gray,Yellow,Green -> 0,1,2): ")
        result = readline()
        pretty_print_response(word,result)
        update_constraints_by_response!(word, result, let_in_pos, let_not_in_pos, let_not_in_word)
        word_set_reduction!(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
        println("Word set length: $(length(word_set))")
        word = predict_best_word(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
        print("Enter your next word [suggested: $word]: ")
        newword = readline()
        if length(newword) != 0
            word = newword
        end
    end
end
function interactive_wordle()
    let_in_pos = Dict{Int,Char}()
    let_not_in_pos = Dict{Char,Vector{Int}}()
    let_not_in_word = Set{Char}()
    word_set = copy(words)
    true_word = rand(wordle_answers)
    print("Enter your starting word [default: reast] :")
    word = readline()
    if length(word) == 0
        word = "reast"
    end
    count = 1
    gameover = false
    while !gameover
        count += 1
        result = score_word(word,true_word)
        pretty_print_response(word,result)
        if result == "22222"
            println("Congratulations!")
            gameover = true
        elseif count > 6
            println("Sorry, you've used all your tries. Better luck next time.")
            gameover = true
        else
            update_constraints_by_response!(word, result, let_in_pos, let_not_in_pos, let_not_in_word)
            word_set_reduction!(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
            println("Word set length: $(length(word_set))")
            word = predict_best_word(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
            println("\nTry $count")
            print("Enter your next word [suggested: $word]: ")
            newword = readline()
            if length(newword) != 0
                word = newword
            end
        end
    end
end
function rank_wordle_strategy(strategy::Symbol)

    wordlist = words
    counts = zeros(length(wordlist))
    for (i,true_word) in ProgressBar(enumerate(wordlist))
        let_in_pos = Dict{Int,Char}()
        let_not_in_pos = Dict{Char,Vector{Int}}()
        let_not_in_word = Set{Char}()
        word_set = copy(words)
        word = "reast"
        if strategy == :random
            word = rand(word_set)
        end
        count = 1
        gameover = false
        while !gameover
            count += 1
            result = score_word(word,true_word)
            if result == "22222"
                gameover = true
                counts[i] = count
            else
                update_constraints_by_response!(word, result, let_in_pos, let_not_in_pos, let_not_in_word)
                word_set_reduction!(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
                #println("Word set length: $(length(word_set))")
                word = predict_best_word(word_set,let_in_pos,let_not_in_pos,let_not_in_word;strategy=strategy,verbose=false)
            end
        end
    end
    return counts
end
