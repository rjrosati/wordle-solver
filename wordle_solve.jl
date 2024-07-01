# based on https://perfectionatic.org/?p=753
#
using ProgressBars

words = readlines(download("https://www-cs-faculty.stanford.edu/~knuth/sgb-words.txt"))

function check_word_set_length(word_set, word, response)
    word_set2 = copy(word_set)
    for i in eachindex(response)
        c = response[i]
        if c == '2'
            filter!(w->w[i]==word[i], word_set2)
        elseif c=='1'
            filter!(w->occursin(word[i],w) && w[i]!=word[i], word_set2)
        else
            filter!(w->!occursin(word[i],w), word_set2)
        end
    end
    return length(word_set2)
end

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
    elseif strategy == :max_entropy
        entropies = zeros(length(word_set))
        for j in eachindex(word_set)
            for i in 1:(3^5-1)
                response = string(digits(i,base=3)...)
                newlen = check_word_set_length(word_set, word_set[j], response)
                if newlen > 0
                    entropies[j] += 1/length(word_set)*1/3^5 * log2(newlen)
                end
            end
        end
        if verbose
            println("maximum entropy: $(maximum(entropies)) bits")
        end
        return word_set[argmax(entropies)]
    elseif strategy == :cond_letter_freq
        # instead of using all of english for letter frequencies, use the remaining wordlist
        # also, tally letters per position
        #function create_letter_lists(word_set)
        #    l1 = Dict{Char,Int}()
        #    l2 = Dict{Char,Int}()
        #    l3 = Dict{Char,Int}()
        #    l4 = Dict{Char,Int}()
        #    l5 = Dict{Char,Int}()
        #    for w in word_set
        #        l1[w[1]] += 1
        #        l2[w[2]] += 1
        #        l3[w[3]] += 1
        #        l4[w[4]] += 1
        #        l5[w[5]] += 1
        #    end
        #    return ""
        #end
        return rand(word_set)

    elseif strategy == :majo
        return rand(word_set)
        #First tries: try a word with the highest density of missing letters, ranked by frequency (no attention to position yet). Do this till you get 3 letters in yellow or green.
        #Create pdf of letters at every position in word, based on the dictionary for words that have those filled green and yellow positions.
        #Take the guess with the most likely word.
        #Create the pdf again and repeat.
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
                  "boing",
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
    suggested_word = "reast"
    print("Enter your starting word [default: reast]: ")
    word = readline()
    if length(word) == 0
        word = suggested_word
    else
        while word ∉ words
            print("Word not in dictionary, try again: ")
            word = readline()
        end
    end
    tries = 1
    while tries <= 6
        print("Enter your response (Gray,Yellow,Green -> 0,1,2): ")
        result = readline()
        while length(result) != 5 || any([r ∉ Set("012") for r in result])
            print("Invalid result, try again: ")
            result = readline()
        end
        pretty_print_response(word,result)
        update_constraints_by_response!(word, result, let_in_pos, let_not_in_pos, let_not_in_word)
        word_set_reduction!(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
	println("Word set length: $(length(word_set)) ($(length(word_set)/length(tword_set)*100)% of suggested word)")
	println("Word set length: $(length(word_set)) ($(length(word_set)/length(tword_set)*100)% of suggested word)")
        if length(word_set) == 1
            println("Your word is:")
            pretty_print_response(only(word_set),"22222")
            break
        end
        suggested_word = predict_best_word(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
        print("Enter your next word [suggested: $suggested_word]: ")
	word = suggested_word
        newword = readline()
        if length(newword) != 0
            while newword ∉ words
                print("Word not in dictionary, try again: ")
                newword = readline()
            end
            word = newword
        end
        tries += 1
    end
end

function interactive_wordle(true_word::String = rand(wordle_answers);suggestions=true,strategy=:letter_freq,hardmode=false)
    true_word = lowercase(true_word)
    if true_word ∉ words
        println("Unfortunately $true_word is not in the dictionary")
        return
    end
    if hardmode
	    error("notimplemented")
    end
    let_in_pos = Dict{Int,Char}()
    let_not_in_pos = Dict{Char,Vector{Int}}()
    let_not_in_word = Set{Char}()
    word_set = copy(words)
    word = ""
    suggested_word = ""
    if suggestions
	suggested_word = "reast"
        print("Enter your starting word [default: reast]: ")
        word = readline()
        if length(word) == 0
            word = "reast"
        else
            while word ∉ words
                print("Word not in dictionary, try again: ")
                word = readline()
            end
        end
    else
        print("Enter your starting word: ")
        word = readline()
        while word ∉ words
            print("Word not in dictionary, try again: ")
            word = readline()
        end
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
            # check ideal performance
	    current_wordset_len = length(word_set)
            tlet_in_pos = copy(let_in_pos)
            tlet_not_in_pos = copy(let_not_in_pos)
            tlet_not_in_word = copy(let_not_in_word)
            tword_set = copy(word_set)
            tresult = score_word(suggested_word,true_word)
            update_constraints_by_response!(suggested_word, tresult, tlet_in_pos, tlet_not_in_pos, tlet_not_in_word)
            word_set_reduction!(tword_set,tlet_in_pos,tlet_not_in_pos,tlet_not_in_word)
            # actualy performance
            update_constraints_by_response!(word, result, let_in_pos, let_not_in_pos, let_not_in_word)
            word_set_reduction!(word_set,let_in_pos,let_not_in_pos,let_not_in_word)
            println("\nTry $count")
            if suggestions
		    println("Word set length: $(length(word_set))  (was $current_wordset_len, suggested word would give: $(length(tword_set)))")
                suggested_word = predict_best_word(word_set,let_in_pos,let_not_in_pos,let_not_in_word,strategy=strategy)
		word = suggested_word
                print("Enter your next word [suggested: $word]: ")
                newword = readline()
                if length(newword) != 0
                    while newword ∉ words
                        print("Word not in dictionary, try again: ")
                        newword = readline()
                    end
                    word = newword
                end
            else
                print("Enter your next word: ")
                newword = readline()
                while newword ∉ words
                    print("Word not in dictionary, try again: ")
                    newword = readline()
                end
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
