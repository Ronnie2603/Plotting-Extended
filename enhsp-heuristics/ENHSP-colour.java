package planners;


import com.hstairs.ppmajal.PDDLProblem.*;
import com.hstairs.ppmajal.conditions.BoolPredicate;
import com.hstairs.ppmajal.domain.PDDLDomain;
import com.hstairs.ppmajal.extraUtils.Utils;
import com.hstairs.ppmajal.expressions.NumFluent;
import com.hstairs.ppmajal.pddl.heuristics.PDDLHeuristic;
import com.hstairs.ppmajal.problem.State;
import com.hstairs.ppmajal.search.SearchHeuristic;
import com.hstairs.ppmajal.transition.TransitionGround;
import org.apache.commons.cli.*;
import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.Pair;

import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/*
 * Copyright (C) 2016-2017 Enrico Scala. Email enricos83@gmail.com.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
/**
 *
 * @author enrico
 *
 *
 *
 */
public class ENHSP {

    private String domainFile;
    private String problemFile;
    private String searchEngineString;
    private String wh;
    private String heuristic = "aibr";
    private String gw;
    private boolean savingSearchSpaceJson = false;
    private String deltaExecution;
    private float depthLimit;
    private String savePlan;
    private int linearEffectsAbstraction = -1;

    private boolean printTrace;
    private String tieBreaking;
    private String planner;
    private String deltaHeuristic;
    private String deltaPlanning;
    private String deltaValidation;
    private boolean helpfulActions;
    private Integer numSubdomains;
    private PDDLProblem problem;
    private boolean pddlPlus;
    private PDDLDomain domain;
    private PDDLDomain domainHeuristic;
    private PDDLProblem heuristicProblem;
    private long overallStart;
    private boolean copyOfTheProblem;
    private boolean anyTime;
    private long timeOut;
    private boolean aibrPreprocessing;
    private SearchHeuristic h;
    private long overallPlanningTime;
    private float endGValue;
    private boolean helpfulTransitions;
    private boolean internalValidation = false;
    private int planLength;
    private String redundantConstraints;
    private String groundingType;
    private boolean naiveGrounding;
    private boolean stopAfterGrounding;
    private boolean printEvents;

    private boolean sdac;
    private boolean onlyPlan;
    private boolean ignoreMetric;
    private boolean printActions;
    private String inputPlan;
    private PrintStream out;
    private boolean autoAnytime;
    private boolean unitCostHeuristic;
    private boolean printAllInfo;
    private boolean printMakespan;
    public static boolean aibrDebug = false;
    private boolean pls;
    private HashSet<BoolPredicate> groundedBooleanFluents = new HashSet<>();

    public ENHSP(boolean copyProblem) {
        copyOfTheProblem = copyProblem;
    }

    public int getPlanLength() {
        return planLength;
    }

    public Pair<PDDLDomain, PDDLProblem> parseDomainProblem(String domainFile, String problemFile, String delta, PrintStream out) {
        try {
            final PDDLDomain localDomain = new PDDLDomain(domainFile);
            //domain.substituteEqualityConditions();
            pddlPlus = !localDomain.getProcessesSchema().isEmpty() || !localDomain.getEventsSchema().isEmpty();
            out.println("Domain parsed");
            final PDDLProblem localProblem = new PDDLProblem(problemFile, localDomain.getConstants(),
                    localDomain.getTypes(), localDomain, out, groundingType, sdac, ignoreMetric,new BigDecimal(deltaPlanning),new BigDecimal(deltaExecution));
            if (!localDomain.getProcessesSchema().isEmpty()) {
                localProblem.setDeltaTimeVariable(delta);
            }
            //this second model is the one used in the heuristic. This can potentially be different from the one used in the execution model. Decoupling it
            //allows us to a have a finer control on the machine
            //the third one is the validation model, where, also in this case we test our plan against a potentially more accurate description
            out.println("Problem parsed");
            out.println("Grounding..");

            if (!localProblem.prepareForSearch(aibrPreprocessing, stopAfterGrounding)) {
                return null;
            }

            groundedBooleanFluents = new HashSet<>();
            for (Object fluent : localProblem.getAllFluents()) {
                if (fluent instanceof BoolPredicate) {
                    groundedBooleanFluents.add((BoolPredicate) fluent);
                }
            }
            if (groundedBooleanFluents.isEmpty() && PDDLProblem.booleanFluents != null) {
                groundedBooleanFluents.addAll(PDDLProblem.booleanFluents);
            }

            
            if (printActions){
                System.out.println(localProblem.getTransitions());
            }
            if (printAllInfo){
                localProblem.printAllInfo();
            }
            if (stopAfterGrounding) {
                System.exit(1);
            }
            return Pair.of(localDomain, localProblem);
        } catch (Exception ex) {
            Logger.getLogger(ENHSP.class.getName()).log(Level.SEVERE, null, ex);
        }
        return null;
    }

    public boolean parsingDomainAndProblem(String[] args) {
        try {
            overallStart = System.currentTimeMillis();
            Pair<PDDLDomain, PDDLProblem> res = parseDomainProblem(domainFile, problemFile, deltaExecution, System.out);
            if (res == null)
                return false;
            domain = res.getKey();
            problem = res.getRight();
            if (pddlPlus) {
                System.out.println("Heuristic Problem Creation");
                res = parseDomainProblem(domainFile, problemFile, deltaHeuristic, new PrintStream(new OutputStream() {
                    public void write(int b) {}}));
                domainHeuristic = res.getKey();
                heuristicProblem = res.getRight();
                copyOfTheProblem = true;
            } else {
                heuristicProblem = problem;
            }
        } catch (Exception ex) {
            ex.printStackTrace();
        }
        return true;
    }

    public void configurePlanner() {
        if (planner != null) {
            setPlanner();
        }
    }

    public record AnytimeConfigurations (String search, String heuristic, Boolean ha, String wh) {}
    LinkedList<AnytimeConfigurations> conf = new LinkedList();

    public void planning() {

        try {
            printStats();
            setHeuristic();
            if (autoAnytime){
                conf.add(new AnytimeConfigurations("lazygbfs","hmrp", true, "4"));
                conf.add(new AnytimeConfigurations("lazywastar","hmrp", false, "8"));
                conf.add(new AnytimeConfigurations("lazywastar","hmrp", false, "4"));
                conf.add(new AnytimeConfigurations("lazywastar","hmrp", false, "2"));
                conf.add(new AnytimeConfigurations("lazywastar","hmrp", false, "1"));
                conf.add(new AnytimeConfigurations("wastar","hmrp", false, "1"));

            }
            int i = 0;
            do {
                if (autoAnytime){
                    if ( conf.size() > i ) {
                        AnytimeConfigurations anytimeConfigurations = conf.get(i);
                        searchEngineString = anytimeConfigurations.search;
                        heuristic = anytimeConfigurations.heuristic;
                        helpfulActions = anytimeConfigurations.ha;
                        wh = anytimeConfigurations.wh;
                    }
                }
                LinkedList sp = search();
                if (printTrace) {
                    String fileName = getProblem().getPddlFileReference() + "_search_" + searchEngineString + "_h_" + heuristic + "_break_ties_" + tieBreaking + ".npt";
                    problem.validate(sp,new BigDecimal(this.deltaExecution), new BigDecimal(deltaExecution), fileName);
                    System.out.println("Numeric Plan Trace saved to " + fileName);
                }
                if (sp == null) {
                    return;
                }else {
                    depthLimit = endGValue;
                    if (anyTime) {
                        System.out.println("NEW COST ==================================================================================>" + depthLimit);
                    }
                    sp = null;
                    System.gc();
                    i++;
                }
            } while (anyTime);
        } catch (Exception ex) {
            Logger.getLogger(ENHSP.class.getName()).log(Level.SEVERE, null, ex);
        }

    }

    public void parseInput(String[] args) {
        Options options = new Options();
        options.addRequiredOption("o", "domain", true, "PDDL domain file");
        options.addRequiredOption("f", "problem", true, "PDDL problem file");
        options.addOption("planner", true, "Fast Preconfgured Planner. For available options look into the code. This overrides all other parameters but domain and problem specs. Commonly used settings are: sat-hmrp (satisficing planning) or opt-hrmax (optimal planning).");
        options.addOption("h", true, "heuristic: options (default is hadd):\n"
                + "aibr, Additive Interval Based relaxation heuristic\n"
                + "hadd, Additive version of subgoaling heuristic\n"
                + "hradd, Additive version of subgoaling heuristic plus redundant constraints\n"
                + "hmax, Hmax for Numeric Planning\n"
                + "hrmax, Hmax for Numeric Planning with redundant constraints\n"
                + "hmrp, heuristic based on MRP extraction\n"
                + "blcost, goal sensitive heuristic (1 to non goal-states, 0 to goal-states)\n"
                + "blind, full blind heuristic (0 to all states)\n"
                + "colour, domain-specific heuristic for the plotting numeric domain\n"
                + "ngc, Numeric Goal Counting Heuristic");
        options.addOption("s", true, "allows to select search strategy (default is WAStar):\n"
                + "gbfs, Greedy Best First Search (f(n) = h(n))\n"
                + "lazygbfs, Greedy Best First Search (f(n) = h(n)) with lazy evaluation\n"
                + "WAStar, WA* (f(n) = g(n) + h_w*h(n))\n"
                + "wa_star_4, WA* (f(n) = g(n) + 4*h(n))\n");
        options.addOption("ties", true, "tie-breaking (default is arbitrary): larger_g, smaller_g, arbitrary");
        options.addOption("dp", "delta_planning", true, "planning decision executionDelta: float");
        options.addOption("de", "delta_execution", true, "planning execution executionDelta: float");
        options.addOption("dh", "delta_heuristic", true, "planning heuristic executionDelta: float");
        options.addOption("dv", "delta_validation", true, "validation executionDelta: float");
        options.addOption("d", "delta", true, "Override other delta_<planning,execuction,validation,heuristic> configurations: float");
        options.addOption("epsilon", true, "epsilon separation: float");
        options.addOption("wh", true, "h-values weight: float");
        options.addOption("sjr", false, "save state space explored in json file");
        options.addOption("ha", "helpful-actions", true, "activate helpful actions in the search");
        options.addOption("pe", "print-events-plan", false, "activate printing of events");

        options.addOption("ht", "helpful-transitions", true, "activate up-to-macro actions");
        options.addOption("sp", true, "Save plan. Argument is filename");
        options.addOption("pt", false, "print state trajectory (Experimental)");
        options.addOption("im", false, "Ignore Metric in the heuristic");
        options.addOption("dap", false, "Disable Aibr Preprocessing");
        options.addOption("red", "redundant_constraints", true, "Choose mechanism for redundant constraints generation among, "
                + "no, brute and smart. No redundant constraints generation is the default");
        options.addOption("gro", "grounding", true, "Activate grounding via internal mechanism, fd or metricff or internal or naive (default is internal)");

        options.addOption("dl", true, "bound on plan-cost: float (Experimental)");
        options.addOption("k", true, "maximal number of subdomains. This works in combination with haddabs: integer");
        options.addOption("anytime", false, "Run in anytime modality. Incrementally tries to find a lower bound. Does not stop until the user decides so");
        options.addOption("timeout", true, "Timeout for anytime modality");
        options.addOption("stopgro", false, "Stop After Grounding");
        options.addOption("ival", false, "Internal Validation");
        options.addOption("sdac", false, "Activate State Dependent Action Cost (Very Experimental!)");
        options.addOption("onlyplan",false,"Print only the plan without waiting");
        options.addOption("print_actions",false,"Print all actions after grounding");
        options.addOption("tolerance",true,"Numeric tolerance in evaluating numeric conditions. Default is 0.00001");
        options.addOption("inputplan",true,"Insert the name of the file containing the plan to validate. This is to be used with ival activated");
        options.addOption("silent",false,"Activate silent modality");
        options.addOption("autoanytime",false,"Activate auto anytime modality. ");
        options.addOption("uch",false,"Pretend all actions cost one in the heuristic");
        options.addOption("npm",false,"PDDL+ feature: Do not print makespan in the plan");
        options.addOption("pai",false,"Print all info before search");
        options.addOption("ea",true,"Effect abstraction mode for non-constants effects. " +
                "Takes integer as an argument, denoting the number of intervals to consider");
        options.addOption("aibr_debug", false, "Enable AIBR debug logging");
        options.addOption("pls", false, "Print the very last state");

        CommandLineParser parser = new DefaultParser();
        try {
            CommandLine cmd = parser.parse(options, args);
            domainFile = cmd.getOptionValue("o");
            problemFile = cmd.getOptionValue("f");
            planner = cmd.getOptionValue("planner");
            heuristic = cmd.getOptionValue("h");
            String optionValue = cmd.getOptionValue("tolerance");
            if (optionValue != null){
                System.out.println(optionValue);
                Utils.tolerance = Double.parseDouble(optionValue);
            }
            
            if (heuristic == null) {
                heuristic = "hadd";
            }
            searchEngineString = cmd.getOptionValue("s");
            if (searchEngineString == null) {
                searchEngineString = "gbfs";
            }
            tieBreaking = cmd.getOptionValue("ties");
            deltaPlanning = cmd.getOptionValue("dp");
            if (deltaPlanning == null) {
                deltaPlanning = "1.0";
            }
            optionValue = cmd.getOptionValue("red");
            if (optionValue == null) {
                redundantConstraints = "no";
            } else {
                redundantConstraints = optionValue;
            }
            optionValue = cmd.getOptionValue("gro");
            if (optionValue != null) {
                groundingType = optionValue;
            } else {
                groundingType = "internal";
            }

            pls = cmd.hasOption("pls");
            String ea = cmd.getOptionValue("ea");
            if (ea != null) {
                if (ea.equals("all")){
                    linearEffectsAbstraction = Integer.MAX_VALUE;
                } else {
                    linearEffectsAbstraction = Integer.parseInt(ea);
                }
            }


            internalValidation = cmd.hasOption("ival");
            this.unitCostHeuristic = cmd.hasOption("uch");

            deltaExecution = cmd.getOptionValue("de");
            if (deltaExecution == null) {
                deltaExecution = "1.0";
            }
            deltaHeuristic = cmd.getOptionValue("dh");
            if (deltaHeuristic == null) {
                deltaHeuristic = "1.0";
            }
            deltaValidation = cmd.getOptionValue("dv");
            if (deltaValidation == null) {
                deltaValidation = "1";
            }
            String temp = cmd.getOptionValue("dl");
            if (temp != null) {
                depthLimit = Float.parseFloat(temp);
            } else {
                depthLimit = -1;
            }

            String timeOutString = cmd.getOptionValue("timeout");
            if (timeOutString != null) {
                timeOut = Long.parseLong(timeOutString) * 1000;
            } else {
                timeOut = Long.MAX_VALUE;
            }

            String delta = cmd.getOptionValue("delta");
            if (delta != null) {
                deltaHeuristic = delta;
                deltaValidation = delta;
                deltaPlanning = delta;
                deltaExecution = delta;
            }
            
            inputPlan = cmd.getOptionValue("inputplan");

            String k = cmd.getOptionValue("k");
            if (k != null) {
                numSubdomains = Integer.parseInt(k);
            } else {
                numSubdomains = 2;
            }

            gw = cmd.getOptionValue("wg");
            wh = cmd.getOptionValue("wh");
            savingSearchSpaceJson = cmd.hasOption("sjr");
            if (cmd.hasOption("silent")){
                out = new PrintStream(new OutputStream() {
                    @Override
                    public void write(int b) throws IOException {
                    }
                });
            }else{
                out = System.out;
            }

            sdac = cmd.hasOption("sdac");
            printMakespan = !cmd.hasOption("npm");
            helpfulActions = cmd.getOptionValue("ha") != null && "true".equals(cmd.getOptionValue("ha"));
            autoAnytime = cmd.hasOption("autoanytime");

            printEvents = cmd.hasOption("pe");

            printTrace = cmd.hasOption("pt");
            savePlan = cmd.getOptionValue("sp");
            onlyPlan = cmd.hasOption("onlyplan");
            anyTime = cmd.hasOption("anytime");
            aibrPreprocessing = !cmd.hasOption("dap");
            stopAfterGrounding = cmd.hasOption("stopgro");
            helpfulTransitions = cmd.getOptionValue("ht") != null && "true".equals(cmd.getOptionValue("ht"));
            ignoreMetric = cmd.hasOption("im");
            printActions = cmd.hasOption("print_actions");
            printAllInfo = cmd.hasOption("pai");
            aibrDebug = cmd.hasOption("aibr-debug");
        } catch (ParseException exp) {
//            Logger.getLogger(ENHSP.class.getName()).log(Level.SEVERE, null, ex);
            System.err.println("Parsing failed.  Reason: " + exp.getMessage());
            HelpFormatter formatter = new HelpFormatter();
            formatter.printHelp("enhsp", options);
            System.exit(-1);
        }

    }

    /**
     * @return the problem
     */
    public PDDLProblem getProblem() {
        return problem;
    }

    public void printStats() {
//        System.out.println("Grounding and Simplification finished");
        System.out.println("|A|:" + getProblem().getActions().size());
        System.out.println("|P|:" + getProblem().getProcessesSet().size());
        System.out.println("|E|:" + getProblem().getEventsSet().size());
        if (pddlPlus) {
            System.out.println("Delta time heuristic model:" + deltaHeuristic);
            System.out.println("Delta time planning model:" + deltaPlanning);
            System.out.println("Delta time search-execution model:" + deltaExecution);
            System.out.println("Delta time validation model:" + deltaValidation);
        }
    }

    private void setPlanner() {
        helpfulTransitions = false;
        helpfulActions = false;
        tieBreaking = "arbitrary";
        switch (planner) {
            case "sat-hmrp":
                heuristic = "hmrp";
                searchEngineString = "gbfs";
                tieBreaking = "arbitrary";
                break;
            case "sat-hmrph":
                heuristic = "hmrp";
                helpfulActions = true;
                searchEngineString = "gbfs";
                tieBreaking = "arbitrary";
                break;
            case "sat-hmrphj":
                heuristic = "hmrp";
                helpfulActions = true;
                helpfulTransitions = true;
                searchEngineString = "gbfs";
                tieBreaking = "arbitrary";
                break;
            case "sat-hmrpff":
                heuristic = "hmrp";
                helpfulActions = false;
                redundantConstraints = "brute";
                helpfulTransitions = false;
                searchEngineString = "gbfs";
                tieBreaking = "arbitrary";
                break;
            case "sat-hadd":
                heuristic = "hadd";
                searchEngineString = "gbfs";
                tieBreaking = "smaller_g";
                break;
            case "sat-aibr":
                heuristic = "aibr";
                searchEngineString = "WAStar";
                tieBreaking = "arbitrary";
                break;
            case "sat-hradd":
                heuristic = "hradd";
                searchEngineString = "gbfs";
                tieBreaking = "smaller_g";
                break;
            case "opt-hmax":
                heuristic = "hmax";
                searchEngineString = "WAStar";
                tieBreaking = "larger_g";
                break;
            case "opt-hlm":
                heuristic = "hlm-lp";
                searchEngineString = "WAStar";
                tieBreaking = "larger_g";
                break;
            case "opt-hlmrd":
                heuristic = "hlm-lp";
                redundantConstraints = "brute";
                searchEngineString = "WAStar";
                tieBreaking = "larger_g";
                break;
            case "opt-hrmax":
                heuristic = "hrmax";
                searchEngineString = "WAStar";
                tieBreaking = "larger_g";
                break;
            case "wastar-optblind":
                heuristic = "blind";
                searchEngineString = "WAStar";
                tieBreaking = "larger_g";
                wh = "1";
                aibrPreprocessing = false;
                break;
            case "wastar-colour":
                heuristic = "colour";
                searchEngineString = "WAStar";
                tieBreaking = "larger_g";
                wh = "1";
                aibrPreprocessing = false;
                break;
            case "greedy-colour":
                heuristic = "colour";
                searchEngineString = "gbfs";
                tieBreaking = "smaller_g";
                wh = "1";
                aibrPreprocessing = false;
                break;
            case "greedy-hadd":
                heuristic = "hadd";
                searchEngineString = "gbfs";
                tieBreaking = "smaller_g";
                wh = "1";
                break;
            default:
                System.out.println("! ====== ! Warning: Unknown planner configuration. Going with default: gbfs with hadd ! ====== !");
                heuristic = "hadd";
                searchEngineString = "gbfs";
                tieBreaking = "smaller_g";
                break;
        }

    }

    private void setHeuristic() {
//        System.out.println("ha:" + helpfulActionsPruning + " ht" + helpfulTransitions);
        if ("colour".equalsIgnoreCase(heuristic)) {
            h = new ColourHeuristic();
        } else {
            h = PDDLHeuristic.getHeuristic(heuristic, heuristicProblem, redundantConstraints, helpfulActions, helpfulTransitions,
                    unitCostHeuristic);
        }
    }


    private class ColourHeuristic implements SearchHeuristic {

        private final Pattern cellPattern =
                Pattern.compile("r(\\d+)c(\\d+)");
        private final Pattern goalPattern =
                Pattern.compile("\\(<=\\s*\\(total-block\\)\\s*([0-9]+(?:\\.[0-9]+)?)\\s*\\)");

        private final Map<String, CellInfo>             cells                = new HashMap<>();
        private final Map<Integer, List<String>>        cellsByRow           = new HashMap<>();
        private final Map<Integer, List<String>>        cellsByCol           = new HashMap<>();
        private final Map<String, List<BoolPredicate>>  colouredPredicates   = new HashMap<>();
        private final Map<Integer, List<BoolPredicate>> blockedRowPredicates = new HashMap<>();
        private final Map<Integer, List<BoolPredicate>> blockedColPredicates = new HashMap<>();

        private final Collection<TransitionGround> transitions;
        private NumFluent totalBlockFluent;
        private double    goalTotalBlock;
        private double    initialTotalBlock;   // saved in constructor for the tie-breaker

        // -----------------------------------------------------------------
        // Constructor
        // -----------------------------------------------------------------

        ColourHeuristic() {
            this.transitions    = problem.getTransitions();
            this.goalTotalBlock = readGoalTotalBlock();
            indexNumericFluents();
            indexBooleanFluents();
            sortCellIndexes();
            // initialTotalBlock is needed by the tie-breaker.
            // It is read from the problem's initial state after all indices
            // have been built (totalBlockFluent and colouredPredicates ready).
            this.initialTotalBlock = currentTotalBlock(problem.getInit());
            System.out.println("[ColourHeuristic] Activated");
            System.out.println("[ColourHeuristic] goalTotalBlock="   + goalTotalBlock
                    + "  initialTotalBlock=" + initialTotalBlock
                    + "  cells=" + cells.size());
        }

        // -----------------------------------------------------------------
        // h(s) = greedy_shots(s)  -  0.001 * blocksRemovedSoFar(s)
        //
        // greedy_shots: per-colour lower bound with directional prefix scans.
        //
        //   B = total-block(s) - goalTotalBlock  blocks to remove.
        //   For each colour c:
        //     - accessible blocks: those reachable via current-state runs.
        //     - inaccessible blocks: hidden behind other colours.
        //   Accessible blocks are handled by minShots (exact minimum given
        //   current runs). Inaccessible blocks fall back to the old global
        //   lower bound: ceil(inaccessible / L_max).
        //
        // tie-breaker: -0.001 * blocksRemovedSoFar
        //   blocksRemovedSoFar = initialTotalBlock - currentTotalBlock >= 0.
        //   Subtracting (not adding) keeps h <= base, so the tie-breaker
        //   never pushes h above the base lower bound — admissibility is
        //   preserved.  Among states with the same shot estimate, those with
        //   more blocks already removed (closer to goal) get a smaller h and
        //   are preferred by GBFS.
        // -----------------------------------------------------------------

        @Override
        public float computeEstimate(State state) {
            double currentTotalBlock  = currentTotalBlock(state);
            double blocksToRemove     = Math.max(0d, currentTotalBlock - goalTotalBlock);

            if (blocksToRemove <= Utils.tolerance) {
                return 0f;
            }

            double blocksRemovedSoFar = Math.max(0d, initialTotalBlock - currentTotalBlock);

            Map<String, Integer>       colorCount = new HashMap<>();
            Map<String, List<Integer>> colorRuns  = new HashMap<>();
            buildColorData(state, colorCount, colorRuns);

            int maxLine = computeMaxLineLength(state);

            // Sort colours by their largest accessible run descending.
            List<Map.Entry<String, List<Integer>>> sorted = new ArrayList<>(colorRuns.entrySet());
            sorted.sort((a, b) -> {
                int maxA = a.getValue().isEmpty() ? 0 : a.getValue().get(0);
                int maxB = b.getValue().isEmpty() ? 0 : b.getValue().get(0);
                return Integer.compare(maxB, maxA);
            });

            double remaining = blocksToRemove;
            float  base      = 0f;

            for (Map.Entry<String, List<Integer>> entry : sorted) {
                if (remaining <= Utils.tolerance) break;

                // Sum of blocks reachable via current prefix scans for this colour.
                double accessible = 0;
                for (int run : entry.getValue()) accessible += run;

                // Only assign what is accessible NOW.
                // Inaccessible blocks of this colour stay in `remaining` and
                // are handled by the safe fallback below, avoiding inflated
                // shot counts for blocks that are currently hidden.
                int    available = colorCount.getOrDefault(entry.getKey(), 0);
                double taken     = Math.min(accessible, Math.min(available, remaining));
                if (taken <= Utils.tolerance) continue;

                // minShots is exact here because taken <= accessible by construction.
                base      += minShots(entry.getValue(), taken);
                remaining -= taken;
            }

            // Blocks not covered by any accessible run (colours with no run at
            // all, or inaccessible tails of partially-covered colours).
            // Fall back to the same global lower bound as the original heuristic:
            // in the best case a future shot removes L_max blocks at once.
            if (remaining > Utils.tolerance) {
                if (maxLine <= 0) return Float.POSITIVE_INFINITY;
                base += (float) Math.ceil(remaining / maxLine);
            }

            // Tie-breaker: subtract a small fraction proportional to progress
            // already made.  This keeps h <= base (admissible) while steering
            // GBFS towards states where more work has been done.
            return base - 0.001f * (float) blocksRemovedSoFar;
        }

        // -----------------------------------------------------------------
        // Minimum shots to remove toRemove blocks of one colour given the
        // list of accessible runs sorted descending.
        // Greedily consume the largest runs first; each run = one shot.
        // Returns Integer.MAX_VALUE only when sum(runs) < toRemove, but
        // computeEstimate never calls this in that situation (taken <= accessible).
        // -----------------------------------------------------------------

        private int minShots(List<Integer> runsSortedDesc, double toRemove) {
            double covered = 0;
            int    shots   = 0;
            for (int run : runsSortedDesc) {
                if (covered >= toRemove) break;
                covered += run;
                shots++;
            }
            return (covered >= toRemove) ? shots : Integer.MAX_VALUE;
        }

        // -----------------------------------------------------------------
        // Directional prefix scans.
        //
        // For each unblocked row or column, skip empty cells until the first
        // real colour, then record the same-colour prefix length and stop at
        // the first different real colour. All runs are grouped by colour and
        // sorted descending for use in minShots().
        // -----------------------------------------------------------------

        private void buildColorData(State state,
                                     Map<String, Integer>       colorCount,
                                     Map<String, List<Integer>> colorRuns) {

            // Count all real blocks per colour (the available pool).
            for (String cell : cells.keySet()) {
                String colour = currentColour(state, cell);
                if (isRealColour(colour)) {
                    colorCount.merge(colour, 1, Integer::sum);
                }
            }

            // Row shots: left → right (senza L-shape)
            for (Map.Entry<Integer, List<String>> rowEntry : cellsByRow.entrySet()) {
                if (isBlocked(blockedRowPredicates.get(rowEntry.getKey()), state)) continue;

                String firstColor = null;
                int    count      = 0;

                for (String cell : rowEntry.getValue()) {
                    String colour = currentColour(state, cell);
                    if (!isRealColour(colour)) continue;

                    if (firstColor == null) {
                        firstColor = colour;
                        count      = 1;
                    } else if (colour.equals(firstColor)) {
                        count++;
                    } else {
                        break;
                    }
                }

                if (firstColor != null && count > 0) {
                    colorRuns.computeIfAbsent(firstColor, k -> new ArrayList<>()).add(count);
                }
            }

            // Column shots: top -> down (cellsByCol sorted by row asc).
            // L-shape does not apply to column shots.
            for (Map.Entry<Integer, List<String>> colEntry : cellsByCol.entrySet()) {
                if (isBlocked(blockedColPredicates.get(colEntry.getKey()), state)) continue;

                String firstColor = null;
                int    count      = 0;

                for (String cell : colEntry.getValue()) {
                    String colour = currentColour(state, cell);
                    if (!isRealColour(colour)) continue;

                    if (firstColor == null) {
                        firstColor = colour;
                        count      = 1;
                    } else if (colour.equals(firstColor)) {
                        count++;
                    } else {
                        break;
                    }
                }

                if (firstColor != null && count > 0) {
                    colorRuns.computeIfAbsent(firstColor, k -> new ArrayList<>()).add(count);
                }
            }

            // Sort each run list descending: largest run first for minShots().
            for (List<Integer> runs : colorRuns.values()) {
                runs.sort((a, b) -> Integer.compare(b, a));
            }
        }

        // -----------------------------------------------------------------
        // Maximum cells in any single unblocked row or column.
        // Used as the fallback denominator for inaccessible blocks.
        // -----------------------------------------------------------------

        private int computeMaxLineLength(State state) {
            int max = 0;
            for (Map.Entry<Integer, List<String>> row : cellsByRow.entrySet())
                if (!isBlocked(blockedRowPredicates.get(row.getKey()), state))
                    max = Math.max(max, row.getValue().size());
            for (Map.Entry<Integer, List<String>> col : cellsByCol.entrySet())
                if (!isBlocked(blockedColPredicates.get(col.getKey()), state))
                    max = Math.max(max, col.getValue().size());
            return max;
        }

        // -----------------------------------------------------------------
        // SearchHeuristic interface
        // -----------------------------------------------------------------

        @Override
        public Object[] getTransitions(boolean onlyHelpfulTransitions) {
            return transitions.toArray();
        }

        @Override
        public Collection<TransitionGround> getAllTransitions() {
            return transitions;
        }

        // -----------------------------------------------------------------
        // Index construction
        // -----------------------------------------------------------------

        private void indexNumericFluents() {
            for (Object fluentObject : heuristicProblem.getNumFluents()) {
                if (!(fluentObject instanceof NumFluent)) continue;
                NumFluent fluent = (NumFluent) fluentObject;
                String name = fluent.getName();
                if ("total-block".equals(name)) {
                    totalBlockFluent = fluent;
                } else if (("row".equals(name) || "col".equals(name))
                        && !fluent.getTerms().isEmpty()) {
                    ensureCell(termName(fluent.getTerms().get(0)));
                }
            }
        }

        private void indexBooleanFluents() {
            for (BoolPredicate predicate : groundedBooleanFluents) {
                String name  = predicate.getName();
                List   terms = predicate.getTerms();
                if ("coloured".equals(name) && terms.size() >= 2) {
                    String cell = termName(terms.get(0));
                    ensureCell(cell);
                    colouredPredicates
                            .computeIfAbsent(cell, key -> new ArrayList<>())
                            .add(predicate);
                } else if ("blockedrow".equals(name) && !terms.isEmpty()) {
                    CellInfo cell = ensureCell(termName(terms.get(0)));
                    blockedRowPredicates
                            .computeIfAbsent(cell.row, key -> new ArrayList<>())
                            .add(predicate);
                } else if ("blockedcol".equals(name) && !terms.isEmpty()) {
                    CellInfo cell = ensureCell(termName(terms.get(0)));
                    blockedColPredicates
                            .computeIfAbsent(cell.col, key -> new ArrayList<>())
                            .add(predicate);
                }
            }
        }

        private void sortCellIndexes() {
            for (List<String> rowCells : cellsByRow.values())
                rowCells.sort((l, r) -> Integer.compare(cells.get(l).col, cells.get(r).col));
            for (List<String> colCells : cellsByCol.values())
                colCells.sort((u, d) -> Integer.compare(cells.get(u).row, cells.get(d).row));
        }

        private CellInfo ensureCell(String cellName) {
            CellInfo known = cells.get(cellName);
            if (known != null) return known;
            Matcher matcher = cellPattern.matcher(cellName);
            int row = 0, col = 0;
            if (matcher.matches()) {
                row = Integer.parseInt(matcher.group(1));
                col = Integer.parseInt(matcher.group(2));
            }
            CellInfo created = new CellInfo(cellName, row, col);
            cells.put(cellName, created);
            cellsByRow.computeIfAbsent(row, key -> new ArrayList<>()).add(cellName);
            cellsByCol.computeIfAbsent(col, key -> new ArrayList<>()).add(cellName);
            return created;
        }

        // -----------------------------------------------------------------
        // State-reading helpers
        // -----------------------------------------------------------------

        private double readGoalTotalBlock() {
            try {
                String  content = Files.readString(Path.of(problemFile));
                Matcher matcher = goalPattern.matcher(content);
                if (matcher.find()) return Double.parseDouble(matcher.group(1));
            } catch (IOException ex) {
                Logger.getLogger(ENHSP.class.getName())
                      .log(Level.WARNING, "Cannot read plotting goal from problem file", ex);
            }
            return 0d;
        }

        private double currentTotalBlock(State state) {
            if (totalBlockFluent != null) return totalBlockFluent.eval(state);
            int count = 0;
            for (String cell : cells.keySet())
                if (isRealColour(currentColour(state, cell))) count++;
            return count;
        }

        private String currentColour(State state, String cell) {
            List<BoolPredicate> predicates = colouredPredicates.get(cell);
            if (predicates == null) return null;
            String nullColour = null;
            for (BoolPredicate predicate : predicates) {
                if (!isSatisfied(predicate, state)) continue;
                String colour = termName(predicate.getTerms().get(1));
                if (isRealColour(colour)) return colour;
                nullColour = colour;
            }
            return nullColour;
        }

        private boolean isBlocked(List<BoolPredicate> predicates, State state) {
            if (predicates == null) return false;
            for (BoolPredicate predicate : predicates)
                if (isSatisfied(predicate, state)) return true;
            return false;
        }

        private boolean isSatisfied(BoolPredicate predicate, State state) {
            try {
                return predicate.isSatisfied(state);
            } catch (RuntimeException ex) {
                return predicate.eval(state);
            }
        }

        private boolean isRealColour(String colour) {
            return colour != null && !"null".equals(colour) && !"wildcard".equals(colour);
        }

        private String termName(Object term) {
            return term.toString();
        }
    }

    private static class CellInfo {
        final String name;
        final int row;
        final int col;

        CellInfo(String name, int row, int col) {
            this.name = name;
            this.row = row;
            this.col = col;
        }
    }

    private LinkedList<ImmutablePair<BigDecimal, TransitionGround>> search() throws Exception {

        PDDLPlanner planner = new PDDLPlanner(searchEngineString,
                heuristic,
                redundantConstraints,
                helpfulTransitions,
                helpfulActions,
                wh != null ? Float.parseFloat(this.wh) : (float) 1.0,
                deltaExecution != null ? new BigDecimal(deltaExecution) : new BigDecimal(1.0),
                deltaPlanning != null ? new BigDecimal(deltaPlanning) : new BigDecimal(1.0),
                tieBreaking == null ? "arbitrary": tieBreaking, savingSearchSpaceJson, depthLimit == -1 ? Float.POSITIVE_INFINITY : depthLimit
                );

        if (savingSearchSpaceJson) {
            Runtime.getRuntime().addShutdownHook(new Thread() {//this is to save json also when the planner is interrupted
                @Override
                public void run() {
                        planner.getSearchSpaceHandle().printJson(
                                getProblem().getPddlFileReference() + ".sp_log");
                }
            });
        }
        overallStart = System.currentTimeMillis();
        PDDLSolution plan = planner.plan(problem, h);
        overallPlanningTime = (System.currentTimeMillis() - overallStart);
        endGValue = plan.gValueAtTheEnd();
        printInfo(plan,pddlPlus,savePlan,plan == null ? null : plan.lastState());
        if (savingSearchSpaceJson) {
            planner.getSearchSpaceHandle().printJson(getProblem().getPddlFileReference() + ".sp_log");
        }
        return plan.rawPlan();
    }

    private void printInfo(PDDLSolution plan, boolean pddlPlus, String savePlan, PDDLState lastState) {
        if (plan.rawPlan() != null) {
            System.out.println("Problem Solved\n");
            System.out.println("Found Plan:");
            printPlan(plan.rawPlan(), pddlPlus, lastState, savePlan);
            System.out.println("\nPlan-Length:" + plan.rawPlan().size());
            planLength = plan.rawPlan().size();
        } else {
            System.out.println("Problem unsolvable");
        }
        if (pddlPlus && plan.rawPlan() != null) {
            System.out.println("Elapsed Time: " + lastState.time);
        }
        System.out.println("Metric (Search):" + plan.gValueAtTheEnd());
        System.out.println("Planning Time (msec): " + overallPlanningTime);
        System.out.println("Heuristic Time (msec): " + plan.stats().heuristicTime());
        System.out.println("Search Time (msec): " + plan.stats().searchTime());
        System.out.println("Expanded Nodes:" + plan.stats().nodesExpanded());
        System.out.println("States Evaluated:" + plan.stats().nodesEvaluated());
        System.out.println("Number of Dead-Ends detected:" + plan.stats().deadEnds());
        System.out.println("Number of Duplicates detected:" + plan.stats().duplicates());
        if (pls){
            System.out.println(lastState);
        }

    }


    private void printPlan(LinkedList<ImmutablePair<BigDecimal, TransitionGround>> plan, boolean temporal, PDDLState par, String fileName) {
        float i = 0f;
        ImmutablePair<BigDecimal, TransitionGround> previous = null;
        List<String> fileContent = new ArrayList();
        boolean startProcess = false;
        int size = plan.size();
        int  j = 0;
        for (ImmutablePair<BigDecimal, TransitionGround> ele : plan) {
            j++;
            if (!temporal) {
                System.out.print(i + ": " + ele.getRight() + "\n");
                if (fileName != null){
                    TransitionGround t = (TransitionGround) ele.getRight();
                    fileContent.add(t.toString());
                }
                i++;
            } else {
                TransitionGround t = (TransitionGround) ele.getRight();
                if (t.getSemantics() == TransitionGround.Semantics.PROCESS) {
                    if (!startProcess) {
                        previous = ele;
                        startProcess = true;
                    }
                    if (j == size) {
                        if (!onlyPlan){
                            System.out.println(previous.getLeft() + ": -----waiting---- " + "[" + par.time + "]");
                        }
                    }
                } else {
                    if (t.getSemantics() != TransitionGround.Semantics.EVENT || printEvents) {
                        if (startProcess) {
                            startProcess = false;
                            if (!onlyPlan){
                                System.out.println(previous.getLeft() + ": -----waiting---- " + "[" + ele.getLeft() + "]");
                            }
                        }
                        System.out.print(ele.getLeft() + ": " + ele.getRight() + "\n");
                        if (fileName != null) {
                            fileContent.add(ele.getLeft() + ": "+ t.toString());
                        }
                    } else {
                        if (j == size) {
                            if (!onlyPlan){
                                System.out.println(previous.getLeft() + ": -----waiting---- " + "[" + ele.getLeft() + "]");
                            }
                        }
                    }
                }
            }
        }

        if (fileName != null) {
            try {
                if (temporal){
                    if (printMakespan)
                        fileContent.add(par.time+": @PlanEND ");
                }
                Files.write(Path.of(fileName), fileContent);

            } catch (IOException ex) {
                Logger.getLogger(ENHSP.class.getName()).log(Level.SEVERE, null, ex);
            }
        }
    }

}
