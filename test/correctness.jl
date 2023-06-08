using Distributions: DiagNormal, PDiagMat
using HMMBase: HMMBase
using HiddenMarkovModels
using Test

function test_correctness(hmm, hmm_init, hmm_base, hmm_init_base; T)
    (; state_seq, obs_seq) = rand(hmm, T)
    obs_mat = reduce(hcat, obs_seq)'

    @testset "Logdensity" begin
        _, logL_base = HMMBase.forward(hmm_base, obs_mat)
        logL = logdensityof(hmm, obs_seq)
        @test logL ≈ logL_base
    end

    @testset "Viterbi" begin
        best_state_seq_base = HMMBase.viterbi(hmm_base, obs_mat)
        best_state_seq = @inferred viterbi(hmm, obs_seq)
        @test isequal(best_state_seq, best_state_seq_base)
    end

    @testset "Forward-backward" begin
        γ_base = HMMBase.posteriors(hmm_base, obs_mat)
        fb = @inferred forward_backward(hmm, obs_seq)
        @test isapprox(fb.γ, γ_base')
    end

    @testset "Baum-Welch" begin
        hmm_est_base, hist_base = HMMBase.fit_mle(
            hmm_init_base, obs_mat; maxiter=100, tol=NaN
        )
        logL_evolution_base = hist_base.logtots
        hmm_est, logL_evolution = @inferred baum_welch(
            hmm_init, [obs_seq]; max_iterations=100, rtol=NaN
        )
        @test isapprox(
            logL_evolution[(begin + 1):end], logL_evolution_base[begin:(end - 1)]
        )
        @test isapprox(initial_distribution(hmm_est.state_process), hmm_est_base.a)
        @test isapprox(transition_matrix(hmm_est.state_process), hmm_est_base.A)
    end
end

N = 5
D = 2

sp = StandardStateProcess(rand_prob_vec(N), rand_trans_mat(N))
op = StandardObservationProcess([DiagNormal(randn(D), PDiagMat(ones(D))) for i in 1:N])
hmm = HMM(sp, op)
hmm_base = HMMBase.HMM(deepcopy(hmm));

sp_init = StandardStateProcess(rand_prob_vec(N), rand_trans_mat(N))
op_init = StandardObservationProcess([DiagNormal(randn(D), PDiagMat(ones(D))) for i in 1:N])
hmm_init = HMM(sp_init, op_init)
hmm_init_base = HMMBase.HMM(deepcopy(hmm_init));

test_correctness(hmm, hmm_init, hmm_base, hmm_init_base; T=100)
