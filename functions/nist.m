function [epsilon_r_results, freq] = nist(a, L, band, ref_port)
    freq = a.Frequencies;
    S = a.Parameters;

    c = physconst('LightSpeed'); % 빛의 속도
    cutoff_freq = 14.051e9; % WR-42 도파관 컷오프 주파수 (TE10 모드)
    lambdac = c / cutoff_freq; % 컷오프 파장
    omega = 2*pi*freq;
    mu0 = 4*pi*1e-7;
    epsilon0 = 8.8541878176e-12;

    % 도파관의 전파 상수 (샘플이 없을 때)
    gamma0 = 1j*sqrt((omega/c).^2 - (2*pi/lambdac)^2);


    %% NRW 방법으로 초기 추정값 계산
    % NRW_mu1_fast 함수를 사용하여 유전율의 초기 근사값을 얻습니다.
    disp('NRW 방법을 사용하여 초기 추정값을 계산합니다...');
    [initial_epsilon_r_guesses, ~] = NRW_mu1_fast(a, band, ref_port);
    disp('초기 추정값 계산 완료.');


    %% 뉴턴 반복법을 이용한 유전율 계산
    epsilon_r_results = zeros(size(freq));

    % 뉴턴 반복법 파라미터
    h_solver = 1e-9;
    max_iter_solver = 400;
    stop_criterion_solver = 1e-6;

    fprintf('주파수 포인트 %d개에 대해 유전율 계산을 시작합니다...\n', length(freq));

    for i = 1:length(freq)
        
        current_S11 = S(1,1,i);
        current_S21 = S(2,1,i);
        current_S12 = S(1,2,i); 
        current_S22 = S(2,2,i);
         
        current_omega = omega(i);
        current_gamma0 = gamma0(i);
        
        % --- 개선 사항 1: 초기 추정값 관리 ---
        % 이전 주파수에서 성공적으로 계산된 값을 현재의 초기 추정값으로 사용합니다.
        % 이는 주파수에 따른 유전율의 연속성을 활용하는 매우 효과적인 방법입니다.
        initial_guess = initial_epsilon_r_guesses(i);
        
        % 풀고자 하는 함수 f(z) = 0, 여기서 z는 epsilon_r        
        f_to_solve = @(eps_r_guess) current_S11*current_S22-current_S12*current_S21 - S11_theoretical(eps_r_guess, current_omega, lambdac, L, current_gamma0, mu0, epsilon0);
        
        % 뉴턴 반복법으로 해 찾기
        [solution, check, ~] = solve_complex_eqn_Newton_iter(f_to_solve, h_solver, max_iter_solver, stop_criterion_solver, initial_guess);
        
        % --- 개선 사항 2: 결과 유효성 검증 ---
        % 수렴에 실패
        if isnan(solution) || abs(check) > 1e-3
            fprintf('\n------------------------------------------------------\n');
            fprintf('!!! DEBUG: 수렴에 실패했거나 결과가 유효하지 않습니다.\n');
            fprintf('  - 주파수 인덱스: %d (%.4f GHz)\n', i, freq(i)/1e9);
            fprintf('  - 계산 시작 시 추정값: %s\n', num2str(initial_guess));
            fprintf('  - 최종 해: %s, 최종 오차 |f(z)|: %e\n', num2str(solution), abs(check));
            fprintf('------------------------------------------------------\n\n');
            
            % 솔버를 디버그 모드로 다시 실행하여 상세 과정 확인 (옵션)
            % solve_complex_eqn_Newton_iter(f_to_solve, h_solver, max_iter_solver, stop_criterion_solver, initial_guess, true);
            
            % 에러를 발생시키는 대신 NaN으로 결과를 저장하고 계속 진행
            epsilon_r_results(i) = NaN;
            % last_successful_guess는 업데이트하지 않고 이전 값을 그대로 유지
            continue; % 다음 주파수로 넘어감
        end
        
        % --- 개선 사항 3: 성공적인 결과 업데이트 ---        
        epsilon_r_results(i) = solution;
        
        
        if mod(i, 20) == 0
            fprintf('%d / %d 완료...\n', i, length(freq));
        end
    end
    fprintf('유전율 계산 완료.\n');



    %% Helper function: 이론적인 S11 값을 계산 (수정 없음)
    function s11_t = S11_theoretical(eps_r, omega_val, lambdac_val, L_val, gamma0_val, mu0_val, epsilon0_val)
        mu_r = 1; % 자성 물질이 아니라고 가정 (mu_r = 1)

        % 샘플 내부의 전파 상수
        gamma_val = 1j*sqrt(eps_r * mu_r * epsilon0_val * mu0_val * omega_val^2 - (2*pi/lambdac_val)^2);

        % 경계면에서의 반사 계수 eq. 2.6
        Gamma_val = (gamma0_val / gamma_val - 1) / (gamma0_val / gamma_val + 1);

        % 샘플 투과 계수
        T_val = exp(-gamma_val * L_val);
        
        % 이론적인 S11(?)  eq 2.8
        s11_t =exp(-2*gamma0_val*(L_val-L_val))*(T_val^2-Gamma_val^2) / (1 - Gamma_val^2 * T_val^2);
    end


    %% solve f(z) = 0, where z and f(z) are both complex numbers
    function [solution, check, iter] = solve_complex_eqn_Newton_iter(f, h, max_iter, stop_criterion, initial_guess, debug_mode)
        if nargin < 6
            debug_mode = false;
        end

        df_dz = @(z) (f(z+h) - f(z-h)) / (2*h);
        
        solution_vec = [real(initial_guess) ; imag(initial_guess)];
        for iter = 1:max_iter
            z_complex = complex(solution_vec(1), solution_vec(2));
            
            % --- 개선 사항 4: 물리적 경계 조건 강제 ---
            % 반복 도중 해가 물리적으로 불가능한 영역으로 가면, 강제로 리셋합니다.
            if real(z_complex) < 1
                if debug_mode, fprintf('  [solver iter %2d] 경고: real(eps_r) < 1. 리셋 시도.\n', iter); end
                z_complex = complex(1.1, imag(z_complex)); % 실수부를 1보다 약간 큰 값으로
                solution_vec = [real(z_complex); imag(z_complex)];
            end
            if imag(z_complex) > 0
                if debug_mode, fprintf('  [solver iter %2d] 경고: imag(eps_r) > 0. 리셋 시도.\n', iter); end
                z_complex = complex(real(z_complex), -1e-4); % 허수부를 음수로 (손실)
                solution_vec = [real(z_complex); imag(z_complex)];
            end
            % ---------------------------------------------
            
            current_error_val = f(z_complex);
            if abs(current_error_val) < stop_criterion
                if debug_mode, fprintf('  - 수렴 완료 (iter: %d)\n', iter); end
                break
            end

            % Jacobian 계산
            temp1 = df_dz(z_complex);
            a = real(temp1); b = imag(temp1);
            J = [a -b ; b a];
        
            % 해 업데이트 방향 계산
        if rcond(J) < 1e-15 % Jacobian이 특이행렬(singular)에 가까운지 확인
            update_direction = pinv(J)*[real(current_error_val) ; imag(current_error_val)];
        else
            update_direction = J\[real(current_error_val) ; imag(current_error_val)];
        end
            
            if any(isnan(update_direction)) || any(isinf(update_direction))
            if debug_mode, fprintf('  [solver iter %2d] 경고: 업데이트 방향 계산 실패. 반복 중단.\n', iter); end
            solution_vec = [NaN; NaN]; break;
            end

            % 감쇠 뉴턴 방법 (Damped Newton's Method) 로직
            alpha = 1; % 초기 보폭 (step size)
            for line_search_iter = 1:10 % 최대 10번 보폭을 줄여봄
                new_solution_vec = solution_vec - alpha * update_direction;
                new_z_complex = complex(new_solution_vec(1), new_solution_vec(2));
                new_error = f(new_z_complex);
                
                if abs(new_error) < abs(current_error_val)
                    break;
                end
                
                alpha = alpha / 2; % 에러가 줄지 않으면 보폭을 절반으로 줄임
                
                if line_search_iter == 10
                    alpha=0; % 개선이 안되면 업데이트 건너뜀
                    break;
                end
            end

            if debug_mode
                fprintf('  [solver iter %2d] z: %s, |f(z)|: %e, alpha: %.4f\n', ...
                        iter, num2str(z_complex), abs(current_error_val), alpha);
            end
            
            solution_vec = solution_vec - alpha * update_direction;
        end
        
        if iter == max_iter && abs(current_error_val) > stop_criterion && debug_mode
            fprintf('  - 최대 반복 횟수에 도달하여 수렴에 실패했습니다.\n');
        end

        solution = complex(solution_vec(1), solution_vec(2));
        check = f(solution); 
    end
end