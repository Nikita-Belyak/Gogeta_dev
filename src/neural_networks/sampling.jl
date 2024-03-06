function optimize_by_sampling!(jump_model, sample_points; enhanced=true, exploitation_rate=0.67)

    input_length = length(jump_model[:x][0, :])
    binary_vars = keys(jump_model[:z].data)
    
    min = objective_sense(jump_model) == MIN_SENSE ? -1 : 1

    extremum = -Inf * min
    optimum = Vector{Float64}()

    for (sample, input) in enumerate(eachcol(sample_points))

        print("$sample ")
        forward_pass!(jump_model, input)

        # fix binary variables
        values = value.(jump_model[:z])
        [fix(jump_model[:z][key], values[key]) for key in binary_vars]

        # unfix the input after forward pass
        unfix.(jump_model[:x][0, :])

        # find hyperplane corner
        optimize!(jump_model)

        x_opt = [value.(jump_model[:x][0, i]) for i in 1:input_length]
        obj_lp = objective_value(jump_model)

        if min * obj_lp > extremum * min
            optimum = x_opt
            extremum = obj_lp
        end

        # restore model
        unfix.(jump_model[:z])
        set_binary.(jump_model[:z])

        # enhanced part
        if enhanced && abs((extremum - obj_lp) / extremum) < exploitation_rate
            while true

                forward_pass!(jump_model, x_opt)

                # solve mip with z=1 values fixed
                values = value.(jump_model[:z])
                [if values[key] == 1 fix(jump_model[:z][key], 1.0) end for key in binary_vars]

                # unfix the input after forward pass
                unfix.(jump_model[:x][0, :])

                # find hyperplane corner
                optimize!(jump_model)

                x_opt = [value.(jump_model[:x][0, i]) for i in 1:input_length]
                obj_mip = objective_value(jump_model)

                # restore model - only fixed variables
                [if values[key] == 1 unfix(jump_model[:z][key]) end for key in binary_vars]
                [if values[key] == 1 set_binary(jump_model[:z][key]) end for key in binary_vars]

                # update optimum and repeat if improved
                if min * obj_mip > obj_lp * min
                    obj_lp = obj_mip
                    if min * obj_lp > extremum * min
                        extremum = obj_lp
                        optimum = x_opt
                    end
                else
                    break
                end
            end
        end
    end

    return optimum, extremum

end